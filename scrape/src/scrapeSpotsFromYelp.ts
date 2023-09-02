import puppeteer, { Browser, ElementHandle, Page, Target } from 'puppeteer';
import { SpotFromYelp } from './types';

const BASE_URL =
	'https://www.yelp.com/search?find_desc=Bars&find_loc=New+York%2C+NY+10001&l=p%3ANY%3ANew_York%3AManhattan%3AEast_Village&sortby=review_count';
const WAIT_DURATION = 3000;

async function fetchFilteredElements(page: Page): Promise<ElementHandle<Element>[]> {
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

async function fetchRestaurantDetails(newPage: Page): Promise<SpotFromYelp> {
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
	let browser: Browser | undefined;
	try {
		browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
		const page = await browser.newPage();
		await page.goto(BASE_URL, { waitUntil: 'networkidle0', timeout: 10000 }).catch((error) => {
			if (error.name !== 'TimeoutError') throw error;
		});

		const elements = await fetchFilteredElements(page);
		const filteredHandles = elements.filter(Boolean);

		console.log(`found ${filteredHandles.length} elements`);

		for (const element of filteredHandles) {
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

			const restaurant = await fetchRestaurantDetails(newPage);
			console.log(restaurant);

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
