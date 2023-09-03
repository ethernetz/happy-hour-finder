import { URL } from 'url';
import { websiteTextDB } from './config.js';
import { scrapeTextFromDomain } from './scrapeTextFromDomain.js';
import { parseTextWithGPT } from './parseTextWithGPT.js';
import { scrapeSpotsFromYelp } from './scrapeSpotsFromYelp.js';

const urls = [
	// 'https://www.phebesnyc.com/',
	// 'https://www.ordercacioevino.com/',
	// 'https://www.coopersnyc.com/',
	// 'https://www.whiteoakny.com/',
	// 'https://www.thegraymarenyc.com/',
	// 'https://www.sweetandvicious.com/',
	// 'http://www.buabar.com/',
	// 'https://www.upstatenyc.com/',
	// 'https://www.tendegreesbar.com/',
	// 'https://www.goodnightsonnynyc.com/',
	// 'https://www.misterparadisenyc.com/',
	// 'https://www.a10kitchen.com/',
	// 'https://www.tilebarnyc.com/',
	// 'https://www.thecopperstillnyc.com/',
	// 'https://the-scratcher.business.site/',
	// 'https://www.downtownsocialnyc.com/',
	// 'https://www.bonnievee.com/',
	// 'http://yucabarnyc.com/',
	// 'https://www.loreleynyc.com/',
	// 'https://www.99centsfreshpizzanyc.com/',
	// 'https://www.verlainenyc.com/',
	// 'http://www.tenbellsnyc.com/',
	// 'http://www.blackcrescentnyc.com/',
	// 'https://www.foolsgoldnyc.com/',
	// 'https://169barnyc.com/',
	// 'https://luckyjacksnyc.com/',
	// 'https://nursebettie.com/',
	// 'https://www.82stanton.com/',
	// 'https://www.theskinny-nyc.com/', // specials should not be happy hour
	// 'https://www.greyladynyc.com/',
	// 'http://jadisnyc.com/', // doesn't recognize happy hour from photo
	// 'https://excusemyfrench-nyc.com/',
	// 'https://www.themagicianbar.com/',
	// 'https://www.set-hospitality.com/',
	// 'https://fivedime.nyc/', //two different times??
	// 'https://www.thecopperstillnyc.com/',
	// 'https://www.thechelseabell.com/',
	// 'http://www.thetippler.com/',
	// 'http://www.barbnyc.com/',
	// 'https://www.porchlightbar.com/?utm_source=GoogleBusinessProfile&utm_medium=Website&utm_campaign=MapLabs', #Cant get the deal
	// 'https://winebarveloce.com/',
	// 'https://junglebirdnyc.com/',
	// 'https://www.themermaidnyc.com/', // switches to subdomain
	// 'https://www.districtlocalnyc.com/',
	// 'http://www.cedricsattheshed.com/?utm_source=GoogleBusinessProfile&utm_medium=Website&utm_campaign=MapLabs',
	'http://juniper2.wpengine.com/',
];

async function processUrls(urls: string[]) {
	for (const url of urls) {
		await websiteTextDB.del(url);
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
		if (!websiteText || !/[a-zA-Z0-9]/.test(websiteText)) continue;

		console.log('making gpt request for', url);
		const response = await parseTextWithGPT(websiteText);
		if (response) {
			console.log(response);
		} else {
			console.log('no response');
		}
	}
}
// processUrls(urls);

scrapeSpotsFromYelp();
