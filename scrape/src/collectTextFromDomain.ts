import puppeteer, { Page } from 'puppeteer';
import { imageAnnotatorClient } from './config';
const NON_TEXTUAL_EXTENSIONS = ['svg', 'jpg', 'png', 'gif'];

export async function collectTextFromDomain(mainUrl: URL): Promise<string> {
	const browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
	const visitedInternalLinks = new Set<string>();
	const visitedImageHrefs = new Set<string>();
	let allText = '';

	function isTextualContent(url: URL): boolean {
		const extension = url.pathname.split('.').pop();
		return !extension || !NON_TEXTUAL_EXTENSIONS.includes(extension);
	}

	async function fetchInternalLinks(page: Page, url: URL): Promise<URL[]> {
		const links = await page.$$eval('[href]', (elements) =>
			elements.map((el) => el.getAttribute('href')),
		);
		const internalLinks: URL[] = [];

		links.forEach((link) => {
			if (!link) return;
			try {
				let linkUrl: URL | undefined;

				// Handle relative URLs by constructing them using mainUrl
				if (link.startsWith('#') || link.startsWith('/')) {
					linkUrl = new URL(link, url);
				} else {
					linkUrl = new URL(link);
				}

				if (linkUrl.hostname === mainUrl.hostname) {
					internalLinks.push(linkUrl);
				}
			} catch (e) {
				// Handle or ignore invalid URLs
			}
		});
		return [...new Set(internalLinks)];
	}

	async function fetchImageHrefs(page: Page) {
		const imageHrefs = await page.$$eval('img', (elements) =>
			elements
				.map((el) => {
					if (!el.src) return undefined;
					try {
						return new URL(el.src);
					} catch (e) {
						return undefined;
					}
				})
				.filter((url) => {
					const extension = url && url.pathname.split('.').pop();
					return extension && ['jpg', 'jpeg', 'png'].includes(extension);
				})
				.map((url) => {
					if (!url) throw Error('blah');
					return url.href;
				}),
		);
		return [...new Set(imageHrefs)];
	}

	async function detectTextFromImage(href: string) {
		if (visitedImageHrefs.has(href)) return;
		visitedImageHrefs.add(href);
		console.log('making image request for', href);
		const [result] = await imageAnnotatorClient.documentTextDetection(href);

		if (result.fullTextAnnotation?.text) {
			allText = `FROM ${href}:\n${result.fullTextAnnotation.text}\n` + allText;
		}
	}

	async function navigateAndCollect(url: URL) {
		if (
			visitedInternalLinks.has(url.href) ||
			url.hostname !== mainUrl.hostname ||
			!isTextualContent(url)
		) {
			return;
		}

		visitedInternalLinks.add(url.href);

		const isHappyHourInUrl = url.href
			.replace(/[^a-zA-Z0-9]/g, '')
			.toLowerCase()
			.includes('happyhour');

		const page = await browser.newPage();
		let imageHrefs: string[] = [];

		try {
			await page.goto(url.href, { waitUntil: 'networkidle0' });
			const text = await page.evaluate(() => document.body.innerText);

			// Handle Happy Hour links and text
			if (isHappyHourInUrl) {
				imageHrefs = await fetchImageHrefs(page);
				allText = `FROM ${url.href}:\n${text}\n` + allText;
			} else if (text.toLowerCase().includes('happy hour')) {
				allText += `FROM ${url.href}:\n${text}\n`;
			}

			const internalLinks = await fetchInternalLinks(page, url);
			await page.close();
			await Promise.all([
				...internalLinks.map(navigateAndCollect),
				...imageHrefs.map(detectTextFromImage),
			]);
		} catch (error) {
			console.error(`Failed to process ${url.href}: ${error}`);
			await page.close();
		}
	}

	await navigateAndCollect(mainUrl);
	await browser.close();

	return allText;
}
