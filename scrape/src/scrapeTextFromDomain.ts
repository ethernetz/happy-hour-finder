import puppeteer, { Page } from 'puppeteer';
import { imageAnnotatorClient, storage } from './config.js';
import fs from 'fs/promises';
import axios from 'axios';

import PQueue from 'p-queue';
const IMG_EXTENSIONS = ['jpg', 'jpeg', 'png'];
const NON_TEXTUAL_EXTENSIONS = ['svg', 'jpg', 'png', 'gif', 'pdf', 'css'];

export async function scrapeTextFromDomain(mainUrl: URL): Promise<string> {
	const browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
	const visitedLinks = new Set<string>();
	const happyHourLinkImagesText: string[] = [];
	const happyHourLinkText: string[] = [];
	const happyHourPdfText: string[] = [];
	const happyHourText: string[] = [];
	const specialsText: string[] = [];
	let taskCount = 0;
	const taskLimit = 25;
	const navigationQueue = new PQueue({ concurrency: 3 });

	async function navigateAndCollectText(recursiveNavigationDepth: number, url: URL) {
		if (url == undefined) return;
		if (visitedLinks.has(cleanURL(url.href))) return;
		if (recursiveNavigationDepth > 3) return;
		console.log('navigating to', url.href);
		visitedLinks.add(cleanURL(url.href));

		const extension = getExtensionFromPathname(url.pathname);

		if (extension && IMG_EXTENSIONS.includes(extension)) {
			console.log('making image request for', url.href);
			const [result] = await imageAnnotatorClient.documentTextDetection(url.href);

			if (
				result.fullTextAnnotation?.text &&
				textIncludesTerm(result.fullTextAnnotation.text, 'happyhour')
			) {
				happyHourLinkImagesText.push(`FROM ${url.href}:\n${result.fullTextAnnotation.text}\n`);
			}
			return;
		}

		taskCount++;

		if (extension === 'pdf') {
			console.log('making pdf request for', url.href);
			const text = await getTextFromPDF(url);
			if (
				(text && textIncludesTerm(text, 'happyhour')) ||
				textIncludesTerm(url.href, 'happyhour')
			) {
				happyHourPdfText.push(`FROM ${url.href}:\n${text}\n`);
			}
			return;
		}

		if (extension && NON_TEXTUAL_EXTENSIONS.includes(extension)) return;

		const page = await browser.newPage();

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
					navigateAndCollectText(recursiveNavigationDepth + 1, frameSources[0]),
				);
			}

			const isHappyHourInUrl = textIncludesTerm(url.href, 'happyhour');

			if (isHappyHourInUrl) {
				happyHourLinkText.push(`FROM ${url.href}:\n${text}\n`);
			} else if (textIncludesTerm(text, 'happyhour')) {
				happyHourText.push(`FROM ${url.href}:\n${text}\n`);
			} else if (textIncludesTerm(text, 'special')) {
				specialsText.push(`FROM ${url.href}:\n${text}\n`);
			}

			const imageHrefs = (await getPageImages(page)).filter((url) => {
				const extension = url && getExtensionFromPathname(url.pathname);
				return extension && ['jpg', 'jpeg', 'png'].includes(extension);
			});
			imageHrefs
				.filter((link) => isHappyHourInUrl || textIncludesTerm(link.href, 'happyhour'))
				.forEach((link) => {
					navigationQueue
						.add(() => navigateAndCollectText(recursiveNavigationDepth + 1, link), {
							priority: 30,
						})
						.catch((error) => {
							console.error(`Failed to process ${link.href}: ${error}`);
						});
				});

			const pageLinks = await getPageLinks(page, url);

			pageLinks
				.filter((link) => {
					const extension = getExtensionFromPathname(link.pathname);
					return extension === 'pdf';
				})
				.forEach((link) => {
					navigationQueue
						.add(() => navigateAndCollectText(recursiveNavigationDepth + 1, link), {
							priority: 25,
						})
						.catch((error) => {
							console.error(`Failed to process ${url.href}: ${error}`);
						});
				});

			pageLinks
				.filter((link) => link.hostname === mainUrl.hostname)
				.forEach((link) => {
					let priority = 1;
					if (link.origin === mainUrl.origin && link.pathname === mainUrl.pathname) {
						priority += 10;
					}

					if (textIncludesTerm(link.href, 'happyhour')) {
						console.log('found happy hour link', link.href);
						priority += 5;
					} else if (textIncludesTerm(link.href, 'special')) {
						priority += 4;
					} else if (textIncludesTerm(link.href, 'menu')) {
						priority += 3;
					}
					navigationQueue
						.add(() => navigateAndCollectText(recursiveNavigationDepth + 1, link), {
							priority,
						})
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
	navigationQueue.on('completed', () => {
		if (taskCount >= taskLimit) {
			navigationQueue.pause();
			navigationQueue.clear();
		}
	});
	await navigationQueue.onIdle();
	await browser.close();

	return `
	${happyHourLinkImagesText.join('\n')}
	${happyHourLinkText.join('\n')}
	${happyHourPdfText.join('\n')}
	${happyHourText.join('\n')}
	${
		!happyHourLinkImagesText.length &&
		!happyHourLinkText.length &&
		!happyHourPdfText.length &&
		!happyHourText.length
			? specialsText.join('\n')
			: ''
	}
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
			.filter((url) => url)
			.map((url) => {
				if (!url) throw Error('URL is undefined, we should have filtered that out');
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
async function getTextFromPDF(url: URL): Promise<string | null> {
	try {
		const bucketName = 'hhf-restuarant-website-images';
		const pathname = url.pathname.replace(/\//g, '_').substring(1);
		const lastIndex = pathname.lastIndexOf('.pdf');
		const pathnameWithoutExtension = lastIndex !== -1 ? pathname.substring(0, lastIndex) : pathname;

		const folderName = url.hostname;
		const imageDestination = `${folderName}/${pathname}`;
		const jsonDestinationPrefix = `${folderName}/${pathnameWithoutExtension}`;
		const bucket = storage.bucket(bucketName);

		// Check if the JSON file already exists
		const [files] = await bucket.getFiles({
			prefix: jsonDestinationPrefix,
		});
		const jsonFile = files.find(
			(file) => file.name.startsWith(jsonDestinationPrefix) && file.name.endsWith('.json'),
		);

		if (jsonFile) {
			console.log('JSON file already exists');
			const [jsonContents] = await jsonFile.download();
			const parsedContents = JSON.parse(jsonContents.toString());
			return parsedContents.responses[0]?.fullTextAnnotation?.text || null;
		} else {
			console.log('JSON file does not exist');
			const downloadedPDFPath = `temp_${pathname}.pdf`;
			try {
				const response = await axios.get(url.href, { responseType: 'arraybuffer' });
				await fs.writeFile(downloadedPDFPath, response.data);
				await bucket.upload(downloadedPDFPath, {
					destination: imageDestination,
				});
			} finally {
				await fs.unlink(downloadedPDFPath);
			}

			const [operation] = await imageAnnotatorClient.asyncBatchAnnotateFiles({
				requests: [
					{
						inputConfig: {
							mimeType: 'application/pdf',
							gcsSource: { uri: `gs://${bucketName}/${imageDestination}` },
						},
						features: [{ type: 'DOCUMENT_TEXT_DETECTION' }],
						outputConfig: {
							gcsDestination: { uri: `gs://${bucketName}/${jsonDestinationPrefix}` },
							batchSize: 100,
						},
					},
				],
			});
			await operation.promise();
			const [filesAfter] = await bucket.getFiles({
				prefix: jsonDestinationPrefix,
			});
			const newJsonFile = filesAfter.find(
				(file) => file.name.startsWith(jsonDestinationPrefix) && file.name.endsWith('.json'),
			);
			if (!newJsonFile) throw new Error('JSON file not found');
			const [jsonContents] = await newJsonFile.download();
			const parsedContents = JSON.parse(jsonContents.toString());
			return parsedContents.responses[0]?.fullTextAnnotation?.text || null;
		}
	} catch (error) {
		console.error(`An error occurred: ${error}`);
		return null;
	}
}

export function textIncludesTerm(text: string, term: string): boolean {
	return text
		.replace(/[^a-zA-Z0-9]/g, '')
		.toLowerCase()
		.includes(term);
}

function cleanURL(inputURL: string): string {
	// Step 1: Remove "http://" prefix if it exists
	if (inputURL.startsWith('http://')) {
		inputURL = inputURL.substring(7);
	}

	// Step 2: Remove trailing slash if it exists
	if (inputURL.endsWith('/')) {
		inputURL = inputURL.slice(0, -1);
	}

	return inputURL;
}

const getExtensionFromPathname = (pathname: string) => {
	return pathname.split('.').pop()?.toLocaleLowerCase();
};
