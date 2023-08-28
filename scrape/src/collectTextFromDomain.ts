import puppeteer, { Page } from 'puppeteer';
import { imageAnnotatorClient } from './config';
const NON_TEXTUAL_EXTENSIONS = ['svg', 'jpg', 'png', 'gif', 'pdf'];
const IMG_EXTENSIONS = ['jpg', 'jpeg', 'png', 'pdf'];

export async function collectTextFromDomain(mainUrl: URL): Promise<string> {
	const browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
	const visitedLinks = new Set<string>();
	let happyHourLinkImagesText = '';
	let happyHourLinkText = '';
	let happyHourText = '';
	let specialsText = '';

	async function navigateAndCollectText(url: URL, innerMainUrl: URL = mainUrl) {
		if (visitedLinks.has(url.href)) {
			return;
		}

		const extension = url.pathname.split('.').pop();

		if (extension && IMG_EXTENSIONS.includes(extension)) {
			visitedLinks.add(url.href);
			console.log('making image request for', url.href);
			const [result] = await imageAnnotatorClient.documentTextDetection(url.href);

			if (result.fullTextAnnotation?.text) {
				happyHourLinkImagesText =
					`FROM ${url.href}:\n${result.fullTextAnnotation.text}\n` + happyHourLinkImagesText;
			}
			return;
		}

		if (extension && NON_TEXTUAL_EXTENSIONS.includes(extension)) return;

		visitedLinks.add(url.href);

		const isHappyHourInUrl = url.href
			.replace(/[^a-zA-Z0-9]/g, '')
			.toLowerCase()
			.includes('happyhour');

		const page = await browser.newPage();
		let imageHrefs: URL[] = [];

		try {
			try {
				await page.goto(url.href, { waitUntil: 'networkidle0', timeout: 20000 });
				// eslint-disable-next-line @typescript-eslint/no-explicit-any
			} catch (error: any) {
				console.log('here');
				if (error.name !== 'TimeoutError') throw error;
			}

			const text = await page.evaluate(() => document.body.innerText);
			if (!text) {
				const frameSources = await getFrameAndIframeSources(page);
				await navigateAndCollectText(frameSources[0], frameSources[0]);
			}

			if (isHappyHourInUrl) {
				imageHrefs = await getPageImages(page);
				happyHourLinkText += `FROM ${url.href}:\n${text}\n`;
			} else if (text.toLowerCase().includes('happy hour')) {
				happyHourText += `FROM ${url.href}:\n${text}\n`;
			} else if (text.toLowerCase().includes('specials')) {
				specialsText += `FROM ${url.href}:\n${text}\n`;
			}

			const internalLinks = (await getPageLinks(page, url)).filter(
				(link) => link.hostname === mainUrl.hostname,
			);
			await page.close();
			await Promise.all(
				[...internalLinks, ...imageHrefs].map((link) => navigateAndCollectText(link, innerMainUrl)),
			);
		} catch (error) {
			console.error(`Failed to process ${url.href}: ${error}`);
			await page.close();
		}
	}

	await navigateAndCollectText(mainUrl);
	await browser.close();

	return `
	${happyHourLinkImagesText}
	${happyHourLinkText}
	${happyHourText}
	${specialsText}
	`;
}

async function getPageLinks(page: Page, url: URL): Promise<URL[]> {
	const links = await page.$$eval('[href]', (elements) =>
		elements.map((el) => el.getAttribute('href')),
	);
	const internalLinkHrefs: string[] = [];

	links.forEach((link) => {
		if (!link) return;
		try {
			let linkUrl: string | undefined;

			// Handle relative URLs by constructing them using mainUrl
			if (link.startsWith('#') || link.startsWith('/')) {
				linkUrl = new URL(link, url).href;
			} else {
				linkUrl = new URL(link).href;
			}

			internalLinkHrefs.push(linkUrl);
		} catch (e) {
			// Handle or ignore invalid URLs
		}
	});
	return [...new Set(internalLinkHrefs)].map((link) => new URL(link));
}

async function getPageImages(page: Page): Promise<URL[]> {
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
	return [...new Set(imageHrefs)].map((link) => new URL(link));
}

async function getFrameAndIframeSources(page: Page): Promise<URL[]> {
	const sources = await page.$$eval('frame, iframe', (elements) =>
		elements.map((el) => el.src).filter((src) => src),
	);

	return [...new Set(sources)].map((source) => new URL(source));
}
