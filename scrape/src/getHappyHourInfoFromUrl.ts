import { websiteTextDB } from './config.js';
import { parseTextWithGPT } from './parseTextWithGPT.js';
import { scrapeTextFromDomain } from './scrapeTextFromDomain.js';
import { HappyHour } from './types.js';

export async function getHappyHourInfoFromUrl(
	url: string,
	deleteCurrentText?: boolean,
): Promise<HappyHour[] | null> {
	deleteCurrentText && (await websiteTextDB.del(url));
	let websiteText: string | undefined;
	try {
		websiteText = await websiteTextDB.get(url);
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
	} catch (err: any) {
		if (err.code === 'LEVEL_NOT_FOUND') {
			websiteText = await scrapeTextFromDomain(new URL(url));
			await websiteTextDB.put(url, websiteText);
		}
	}

	if (!websiteText || !/[a-zA-Z0-9]/.test(websiteText))
		console.log('no website text found for', url);
	if (!websiteText || !/[a-zA-Z0-9]/.test(websiteText)) return null;

	console.log('making gpt request for', url);
	return await parseTextWithGPT(websiteText);
}
