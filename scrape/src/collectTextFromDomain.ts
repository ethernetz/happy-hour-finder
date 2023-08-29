import puppeteer, { Page } from 'puppeteer';
import { imageAnnotatorClient } from './config.js';
import PQueue from 'p-queue';
const NON_TEXTUAL_EXTENSIONS = ['svg', 'jpg', 'png', 'gif', 'pdf'];
const IMG_EXTENSIONS = ['jpg', 'jpeg', 'png', 'pdf'];

export async function collectTextFromDomain(mainUrl: URL): Promise<string> {
	const browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
	const visitedLinks = new Set<string>();
	const happyHourLinkImagesText: string[] = [];
	const happyHourLinkText: string[] = [];
	const happyHourText: string[] = [];
	const specialsText: string[] = [];
	const navigationQueue = new PQueue({ concurrency: 3 });

	async function navigateAndCollectText(
		recursiveNavigationDepth: number,
		url: URL,
		innerMainUrl: URL = mainUrl,
	) {
		if (recursiveNavigationDepth > 3) return;

		if (visitedLinks.has(url.href)) {
			return;
		}

		const extension = url.pathname.split('.').pop();

		if (extension && IMG_EXTENSIONS.includes(extension)) {
			visitedLinks.add(url.href);
			console.log('making image request for', url.href);
			const [result] = await imageAnnotatorClient.documentTextDetection(url.href);

			if (result.fullTextAnnotation?.text) {
				happyHourLinkImagesText.push(`FROM ${url.href}:\n${result.fullTextAnnotation.text}`);
			}
			return;
		}

		if (extension && NON_TEXTUAL_EXTENSIONS.includes(extension)) return;

		visitedLinks.add(url.href);

		console.log('visiting', url.href);

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
				if (error.name !== 'TimeoutError') throw error;
			}

			const text = await page.evaluate(() => document.body.innerText);
			if (!text) {
				const frameSources = await getFrameAndIframeSources(page);
				navigationQueue.add(() =>
					navigateAndCollectText(recursiveNavigationDepth + 1, frameSources[0], frameSources[0]),
				);
			}

			if (isHappyHourInUrl) {
				imageHrefs = await getPageImages(page);
				happyHourLinkText.push(`FROM ${url.href}:\n${text}`);
			} else if (text.toLowerCase().includes('happy hour')) {
				happyHourText.push(`FROM ${url.href}:\n${text}`);
			} else if (text.toLowerCase().includes('specials')) {
				specialsText.push(`FROM ${url.href}:\n${text}`);
			}

			const internalLinks = (await getPageLinks(page, url)).filter(
				(link) => link.hostname === mainUrl.hostname,
			);
			[...internalLinks, ...imageHrefs].forEach((link) => {
				navigationQueue
					.add(() => navigateAndCollectText(recursiveNavigationDepth + 1, link, innerMainUrl))
					.catch((error) => {
						console.error(`Failed to process ${link.href}: ${error}`);
					});
			});
			page.close();
		} catch (error) {
			console.error(`Failed to process ${url.href}: ${error}`);
			await page.close();
		}
	}

	navigationQueue.add(() => navigateAndCollectText(0, mainUrl));
	await navigationQueue.onIdle();
	await browser.close();

	return `
	${happyHourLinkImagesText.join('\n')}
	${happyHourLinkText.join('\n')}
	${happyHourText.join('\n')}
	${specialsText.join('\n')}
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
