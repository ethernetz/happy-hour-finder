import puppeteer, { Page } from 'puppeteer';
import { URL } from 'url';
import OpenAI from 'openai';
import { OPENAI_API_KEY } from './config';
import path from 'path';
import { Level } from 'level';

const websiteTextPath = path.resolve(__dirname, '..', 'website-text'); // Go up one level to project root
const websiteTextDB = new Level(websiteTextPath, { valueEncoding: 'json' });

if (!OPENAI_API_KEY) throw new Error('OPENAI_API_KEY not set');
const openai = new OpenAI({
	apiKey: OPENAI_API_KEY,
});
const NON_TEXTUAL_EXTENSIONS = ['svg', 'jpg', 'png', 'gif'];

async function collectTextFromDomain(mainUrl: URL) {
	const browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
	const visitedUrls = new Set<string>();
	let allText = '';
	let stopCrawling = false;
	let textFromHappyHourLink: string | undefined;

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
		return internalLinks;
	}

	async function navigateAndCollect(url: URL) {
		if (visitedUrls.has(url.href) || url.hostname !== mainUrl.hostname || !isTextualContent(url)) {
			return;
		}

		visitedUrls.add(url.href);

		const isHappyHourInUrl = url.href
			.replace(/[^a-zA-Z0-9]/g, '')
			.toLowerCase()
			.includes('happyhour');
		if (isHappyHourInUrl) stopCrawling = true;

		const page = await browser.newPage();

		try {
			await page.goto(url.href, { waitUntil: 'networkidle0' });
			const text = await page.evaluate(() => document.body.innerText);

			// Handle Happy Hour links and text
			if (isHappyHourInUrl) {
				console.log('Found happy hour in url', url.href);
				textFromHappyHourLink = text;
			} else if (text.toLowerCase().includes('happy hour')) {
				allText += `FROM ${url.href}:\n${text}\n`;
			}

			if (stopCrawling) return;

			const internalLinks = await fetchInternalLinks(page, url);
			await page.close();
			await Promise.all(internalLinks.map(navigateAndCollect));
		} catch (error) {
			console.error(`Failed to process ${url.href}: ${error}`);
			await page.close();
		}
	}

	await navigateAndCollect(mainUrl);
	await browser.close();

	if (textFromHappyHourLink) {
		console.log(textFromHappyHourLink);
		return textFromHappyHourLink;
	}

	return allText;
}

const urls = [
	// 'https://www.phebesnyc.com/',
	// 'https://www.ordercacioevino.com/',
	// 'https://www.coopersnyc.com/',
	// 'https://www.whiteoakny.com/',
	// 'https://www.thegraymarenyc.com/',
	'https://www.sweetandvicious.com/',
];

const functions: OpenAI.Chat.Completions.CompletionCreateParams.Function[] = [
	{
		name: 'logHappyHourDealIntoDatabase',
		description: 'Logs happy hour deal into database.',
		parameters: {
			type: 'object',
			properties: {
				days: { type: 'array', items: { type: 'string' } },
				startTime: { type: 'string' },
				endTime: { type: 'string' },
				deal: { type: 'string' },
			},
			required: ['days', 'startTime', 'endTime', 'deal'],
		},
	},
];

async function processUrls(urls: string[]) {
	for (const url of urls) {
		let websiteText: string | undefined;
		try {
			websiteText = await websiteTextDB.get(url);
			// eslint-disable-next-line @typescript-eslint/no-explicit-any
		} catch (err: any) {
			if (err.code === 'LEVEL_NOT_FOUND') {
				websiteText = await collectTextFromDomain(new URL(url));
				await websiteTextDB.put(url, websiteText);
			}
		}

		if (!websiteText) console.log('no website text found for', url);
		if (!websiteText) continue;

		console.log('making request for', url);
		const response = await openai.chat.completions.create({
			messages: [
				{
					role: 'user',
					content: `
					Your primary objective is to parse the following website text log the happy hour deal into the database using the logHappyHourDealIntoDatabase method.  
					If there is no mention of a happy hour or you're uncertain, do not log the happy hour into the database.

					Important: Fabricating details is unacceptable. Only invoke 'logHappyHourDealIntoDatabase' if the website text explicitly mentions a happy hour.

					Below is the text data extracted from the website:

					${truncate(websiteText)}
					`,
				},
			],
			model: 'gpt-4',
			functions: functions,
		});
		const responseMessage = response.choices[0].message;
		if (responseMessage.function_call) {
			console.log(url, responseMessage.function_call.arguments);
		} else {
			console.log(url, 'fake', responseMessage);
		}
	}
}

processUrls(urls);

import { getEncoding } from 'js-tiktoken';

const truncate = (inputString: string) => {
	// Step 1: Get the encoder for a particular model
	const encoder = getEncoding('cl100k_base');

	// Step 2: Tokenize the input string
	const tokens = encoder.encode(inputString);

	// Step 3: Truncate the token list if it's too long
	const truncatedTokens = tokens.length > 4000 ? tokens.slice(0, 3700) : tokens;

	// Step 4: Decode the truncated token list back into a string
	const truncatedString = encoder.decode(truncatedTokens);

	// Step 5: Return the truncated string
	return truncatedString;
};
