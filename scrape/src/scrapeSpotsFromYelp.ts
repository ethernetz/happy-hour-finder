import puppeteer, { Browser, ElementHandle, Page, Target } from 'puppeteer';
import { Spot, SpotFromYelp } from './types';
import mongoClientPromise, { geocodingClient } from './config.js';

const BASE_URL =
	'https://www.yelp.com/search?find_desc=Bars&find_loc=New+York%2C+NY+10001&l=p%3ANY%3ANew_York%3AManhattan%3AEast_Village&sortby=review_count';
const WAIT_DURATION = 3000;

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

async function fetchSpotDetailsFromSpotPage(newPage: Page): Promise<SpotFromYelp> {
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
		if (!address)
			throw new Error("Couldn't find address. This should never happen. Please investigate.");

		// Get the URL
		const businessWebsiteElements = Array.from(document.querySelectorAll('p'));
		const businessWebsiteElement = businessWebsiteElements.find(
			(el) => el.textContent === 'Business website',
		);
		const urlElement =
			businessWebsiteElement?.parentElement?.querySelector<HTMLAnchorElement>('a[href]');
		const yelpRedirectHref = urlElement ? urlElement.href : null;
		if (!yelpRedirectHref)
			throw new Error(
				"Couldn't find yelpRedirectHref. This should never happen. Please investigate.",
			);
		const urlSearchParam = new URL(yelpRedirectHref).searchParams.get('url');
		if (!urlSearchParam)
			throw new Error(
				"Couldn't find urlSearchParam. This should never happen. Please investigate.",
			);
		const url = decodeURIComponent(urlSearchParam);

		return {
			name,
			address,
			url,
		};
	});
}

export async function scrapeSpotsFromYelp() {
	const mongoClient = await mongoClientPromise;
	const db = mongoClient.db('happyHourDB');
	const collection = db.collection('spots');
	await collection.createIndex({ uniqueName: 1 }, { unique: true });
	await collection.createIndex({ coordinates: '2dsphere' });

	let browser: Browser | undefined;
	try {
		browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
		const page = await browser.newPage();
		await page.goto(BASE_URL, { waitUntil: 'networkidle0', timeout: 10000 }).catch((error) => {
			if (error.name !== 'TimeoutError') throw error;
		});

		const spotCards = await fetchSpotCardsListPage(page);

		for (const element of spotCards) {
			const restaurantName = await element.evaluate((el) =>
				(el as HTMLElement).innerText.replace(/^\d+\.\s/, ''),
			);
			const uniqueName = `${restaurantName}_eastvilliage`;
			const existingSpot = await collection.findOne({ uniqueName });
			if (existingSpot) {
				console.log(`skipping ${uniqueName}`);
				continue;
			}
			console.log(`processing ${uniqueName}`);

			const newPagePromise = new Promise<Page | null>((resolve) => {
				browser?.once('targetcreated', async (target: Target) => {
					resolve(await target.page());
				});
			});

			element.click();
			const newPage = await newPagePromise;

			if (!newPage)
				throw new Error('newPage is null. This should never happen. Please investigate.');

			await newPage
				.waitForNavigation({ waitUntil: 'networkidle0', timeout: 10000 })
				.catch((error) => {
					if (error.name !== 'TimeoutError') throw error;
				});

			const spotDetails = await fetchSpotDetailsFromSpotPage(newPage);
			const response = await geocodingClient
				.forwardGeocode({
					query: spotDetails.address,
					countries: ['us'],
					types: ['address'],
					limit: 1,
				})
				.send();
			const [latitude, longitude] = response.body.features[0].geometry.coordinates;
			const fullRestaurantInfo: Omit<Spot, '_id'> = {
				...spotDetails,
				uniqueName,
				checkedForHappyHours: false,
				coordinates: {
					type: 'Point',
					coordinates: [longitude, latitude],
				},
			};

			console.log(fullRestaurantInfo);
			await collection.insertOne(fullRestaurantInfo);

			await new Promise((resolve) => setTimeout(resolve, WAIT_DURATION));
			await newPage.close();
		}
	} catch (error) {
		console.log(error);
		throw error;
	} finally {
		console.log('closing');
		await browser?.close();
	}
}
