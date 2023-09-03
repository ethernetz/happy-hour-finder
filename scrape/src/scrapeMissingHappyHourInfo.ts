import mongoClientPromise from './config.js';
import { getHappyHourInfoFromUrl } from './getHappyHourInfoFromUrl.js';
import { Spot } from './types.js';

export async function scrapeMissingHappyHourInfo() {
	const mongoClient = await mongoClientPromise;
	const db = mongoClient.db('happyHourDB');
	const collection = db.collection<Spot>('spots');

	const query = {
		$and: [
			{ url: { $exists: true, $ne: null } },
			{
				$or: [{ checkedForHappyHour: { $exists: false } }, { checkedForHappyHour: false }],
			},
		],
	};
	const cursor = collection.find(query);
	for await (const doc of cursor) {
		console.dir(doc);
		if (!doc.url) throw new Error('doc.url is null');
		const happyHourInfo = await getHappyHourInfoFromUrl(doc.url);
		if (!happyHourInfo) {
			console.log('no happy hour info found for', doc.url);
			collection.updateOne({ _id: doc._id }, { $set: { checkedForHappyHour: true } });
		} else {
			console.log('happy hour info found for', doc.url);
			console.log(happyHourInfo);
			collection.updateOne(
				{ _id: doc._id },
				{ $set: { checkedForHappyHour: true, happyHours: happyHourInfo } },
			);
		}
	}
}
