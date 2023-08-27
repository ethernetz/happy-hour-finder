import puppeteer, { Page } from 'puppeteer';
const NON_TEXTUAL_EXTENSIONS = ['svg', 'jpg', 'png', 'gif'];

export async function collectTextFromDomain(mainUrl: URL): Promise<string> {
	const browser = await puppeteer.launch({ headless: false, args: ['--enable-logging'] });
	const visitedUrls = new Set<string>();
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

		const page = await browser.newPage();

		try {
			await page.goto(url.href, { waitUntil: 'networkidle0' });
			const text = await page.evaluate(() => document.body.innerText);

			// Handle Happy Hour links and text
			if (isHappyHourInUrl) {
				console.log('Found happy hour in url', url.href);
				allText = `FROM ${url.href}:\n${text}\n` + allText;
			} else if (text.toLowerCase().includes('happy hour')) {
				allText += `FROM ${url.href}:\n${text}\n`;
			}

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

	return allText;
}
