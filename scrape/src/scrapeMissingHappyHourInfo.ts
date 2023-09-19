import { mongoClientPromise } from './config.js';
import { getGooglePlaceId } from './getGooglePlaceId.js';
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
				$or: [{ checkedForHappyHours: { $exists: false } }, { checkedForHappyHours: false }],
			},
		],
	};
	const cursor = collection.find(query);
	for await (const doc of cursor) {
		if (!doc.url) throw new Error('doc.url is null');
		const happyHours = await getHappyHourInfoFromUrl(doc.url);
		if (!happyHours) {
			console.log('no happy hour info found for', doc.url);
			collection.updateOne({ _id: doc._id }, { $set: { checkedForHappyHours: true } });
		} else {
			console.log('happy hour info found for', doc.url);
			console.log(happyHours);
			collection.updateOne(
				{ _id: doc._id },
				{ $set: { checkedForHappyHours: true as const, happyHours: happyHours } },
			);
		}
	}
}

export async function addMissingGooglePlaceId() {
	const mongoClient = await mongoClientPromise;
	const db = mongoClient.db('happyHourDB');
	const collection = db.collection<Spot>('spots');

	const query = {
		$or: [{ googlePlaceId: { $exists: false } }],
	};
	const cursor = collection.find(query);
	for await (const doc of cursor) {
		if (!doc.name || !doc.address) throw new Error('Either doc.name or doc.address is null');

		const googlePlaceId = await getGooglePlaceId(doc.name, doc.address);

		if (!googlePlaceId) {
			console.log('No Google Place ID found for', doc.name);
			throw new Error('No Google Place ID found');
		} else {
			console.log('Google Place ID found for', doc.name);
			console.log(googlePlaceId);
			collection.updateOne({ _id: doc._id }, { $set: { googlePlaceId: googlePlaceId } });
		}
	}
}
