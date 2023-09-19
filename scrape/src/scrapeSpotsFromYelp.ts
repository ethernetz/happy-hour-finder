import puppeteer, { Browser, ElementHandle, Page, Target } from 'puppeteer';
import { Spot, SpotFromYelp } from './types';
import { mongoClientPromise, geocodingClient } from './config.js';
import { getHappyHourInfoFromUrl } from './getHappyHourInfoFromUrl.js';
import { getGooglePlaceId } from './getGooglePlaceId';

const BASE_URL =
	'https://www.yelp.com/search?find_desc=Bars&find_loc=Greenwich+Village%2C+Manhattan%2C+NY&attrs=HappyHour&sortby=review_count&l=p%3ANY%3ANew_York%3AManhattan%3AGreenwich_Village&start=0';

async function fetchSpotCardsListPage(page: Page): Promise<ElementHandle<Element>[]> {
	const elements = await page.$$('[class^=" businessName"]');
	const possibleFilteredElements = await Promise.all(
		elements.map(async (element) => {
			const innerText = await element.evaluate((el) => (el as HTMLElement).innerText);
			return /^\d+\.\s/.test(innerText) ? element : null;
		}),
	);

	const filteredElements = possibleFilteredElements.filter(Boolean) as ElementHandle<Element>[];
	return filteredElements;
}

async function fetchSpotDetailsFromSpotPage(newPage: Page): Promise<SpotFromYelp | null> {
	return newPage.evaluate(() => {
		// Get the name
		const nameElement = document.querySelector('[class^=" headingLight"]');
		const name = nameElement ? nameElement.textContent : null;
		if (!name) throw new Error("Couldn't find name. This should never happen. Please investigate.");

		// Get the address
		const getDirectionsElements = Array.from(document.querySelectorAll('a'));
		const getDirectionsElement = getDirectionsElements.find(
			(el) => el.textContent === 'Get Directions',
		);
		const addressElement = getDirectionsElement?.parentElement?.parentElement;
		const address = addressElement
			? addressElement.textContent?.replace('Get Directions', '').trim()
			: null;
		if (!address) return null;

		// Get the URL
		const businessWebsiteElements = Array.from(document.querySelectorAll('p'));
		const businessWebsiteElement = businessWebsiteElements.find(
			(el) => el.textContent === 'Business website',
		);
		const urlElement =
			businessWebsiteElement?.parentElement?.querySelector<HTMLAnchorElement>('a[href]');
		const yelpRedirectUrl = urlElement ? urlElement.href : null;
		return {
			name,
			address,
			yelpRedirectUrl,
		};
	});
}
export async function scrapeSpotsFromYelpPage(browser: Browser, page: Page): Promise<void> {
	const mongoClient = await mongoClientPromise;
	const db = mongoClient.db('happyHourDB');
	const collection = db.collection('spots');
	await collection.createIndex({ uniqueName: 1 }, { unique: true });
	await collection.createIndex({ coordinates: '2dsphere' });
	const spotCards = await fetchSpotCardsListPage(page);

	for (const element of spotCards) {
		try {
			const uniqueName = await getUniqueNameFromElement(element);
			let existingSpot = await collection.findOne({ uniqueName });
			if (existingSpot !== null) {
				console.log(`found ${uniqueName} in mongo, skipping scrapeSpotsFromYelpPage`);
				continue;
			}
			console.log(`scraping ${uniqueName}`);

			const yelpSpotPage = await navigateToSpotPage(browser, element);
			const spotDetails = await fetchSpotDetailsFromSpotPage(yelpSpotPage);
			yelpSpotPage.close();
			if (!spotDetails) {
				console.log('spotDetails not found. Skipping.');
				continue;
			}

			existingSpot = await collection.findOne({ address: spotDetails.address });
			if (existingSpot !== null) {
				console.log(`found ${spotDetails.address} in mongo, skipping scrapeSpotsFromYelpPage`);
				continue;
			}

			const { latitude, longitude } = await getCoordinates(spotDetails.address);

			const googlePlaceId = await getGooglePlaceId(spotDetails.name, spotDetails.address);

			if (!spotDetails.yelpRedirectUrl) {
				const fullSpotInfo: Spot = {
					name: spotDetails.name,
					address: spotDetails.address,
					url: null,
					uniqueName,
					checkedForHappyHours: true,
					coordinates: {
						type: 'Point',
						coordinates: [longitude, latitude],
					},
					happyHours: null,
					googlePlaceId,
				};
				console.log(`spot ${uniqueName} has no url, inserting into mongo`);
				console.log(fullSpotInfo);
				await collection.insertOne(fullSpotInfo);
				continue;
			}
			const spotWebsiteUrl = await getSpotWebsiteUrl(browser, spotDetails.yelpRedirectUrl);

			const happyHours = await getHappyHourInfoFromUrl(spotWebsiteUrl);

			const fullSpotInfo: Spot = {
				name: spotDetails.name,
				address: spotDetails.address,
				url: spotWebsiteUrl,
				uniqueName,
				checkedForHappyHours: true,
				happyHours: happyHours,
				coordinates: {
					type: 'Point',
					coordinates: [longitude, latitude],
				},
				googlePlaceId,
			};
			console.log(fullSpotInfo);
			await collection.insertOne(fullSpotInfo);
		} catch (e) {
			console.error(`Error processing element: ${e}`);
		}
	}
}

async function getUniqueNameFromElement(element: ElementHandle): Promise<string> {
	// Extract unique name
	const restaurantName = await element.evaluate((el) =>
		(el as HTMLElement).innerText.replace(/^\d+\.\s/, ''),
	);
	return `${restaurantName}_greenwhich`;
}

async function navigateToSpotPage(browser: Browser, element: ElementHandle): Promise<Page> {
	const yelpSpotPagePromise = new Promise<Page | null>((resolve) => {
		browser.once('targetcreated', async (target: Target) => {
			resolve(await target.page());
		});
	});
	element.click();
	const yelpSpotPage = await yelpSpotPagePromise;
	if (!yelpSpotPage) {
		throw new Error('New page is null. This should never happen. Please investigate.');
	}
	await yelpSpotPage
		.waitForNavigation({ waitUntil: 'networkidle0', timeout: 10000 })
		.catch((error) => {
			if (error.name !== 'TimeoutError') throw error;
		});
	return yelpSpotPage;
}

async function getSpotWebsiteUrl(browser: Browser, yelpRedirectUrl: string): Promise<string> {
	const spotWebsitePage = await browser.newPage();
	await spotWebsitePage
		.goto(yelpRedirectUrl, {
			waitUntil: 'networkidle0',
			timeout: 10000,
		})
		.catch((error) => {
			if (error.name !== 'TimeoutError') throw error;
		});
	await spotWebsitePage.waitForNetworkIdle({ idleTime: 2000, timeout: 7000 }).catch((error) => {
		if (error.name !== 'TimeoutError') throw error;
	});
	const spotWebsiteUrl = spotWebsitePage.url();
	await spotWebsitePage.close();
	return spotWebsiteUrl;
}

async function getCoordinates(address: string): Promise<{ latitude: number; longitude: number }> {
	const response = await geocodingClient
		.forwardGeocode({
			query: address,
			countries: ['us'],
			types: ['address'],
			limit: 1,
		})
		.send();
	const [longitude, latitude] = response.body.features[0].geometry.coordinates;
	return { latitude, longitude };
}

export async function scrapeSpotsFromYelp() {
	let browser: Browser | undefined;
	try {
		browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
		const page = await browser.newPage();
		await page.goto(BASE_URL, { waitUntil: 'networkidle0', timeout: 10000 }).catch((error) => {
			if (error.name !== 'TimeoutError') throw error;
		});

		for (let i = 0; i < 10; i++) {
			await scrapeSpotsFromYelpPage(browser, page);

			const nextButton = await page.$('a[class^="next-link"]');

			if (nextButton) {
				await nextButton.click();
				await page
					.waitForNavigation({ waitUntil: 'networkidle0', timeout: 10000 })
					.catch((error) => {
						if (error.name !== 'TimeoutError') throw error;
					});
			} else {
				console.log('Next button not found. Exiting loop.');
				break;
			}
		}
	} catch (error) {
		console.log(error);
		throw error;
	} finally {
		console.log('closing');
		await browser?.close();
	}
}
