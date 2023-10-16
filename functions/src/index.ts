import * as functions from 'firebase-functions';
import { MongoClient } from 'mongodb';

let client: MongoClient | null;

const getClient = async () => {
	const mongoDbConnectionString = process.env.MONGO_DB_CONNECTION_STRING;
	if (!mongoDbConnectionString)
		throw new functions.https.HttpsError('internal', 'Could not find MongoDB connection string');
	if (!client) {
		const mClient = new MongoClient(mongoDbConnectionString, {});
		client = await mClient.connect();
		functions.logger.log('Connected to MongoDB');
	} else {
		functions.logger.log('Using existing MongoDB connection');
	}
	return client;
};

type CurrentLocation = {
	latitude: number;
	longitude: number;
};

// Specify the secret name in runWith parameter
export const helloWorld = functions
	.runWith({ secrets: ['MONGO_DB_CONNECTION_STRING'] })
	.https.onCall(async ({ latitude, longitude }: CurrentLocation) => {
		functions.logger.log('Current location:', latitude, longitude);
		try {
			const spots = (await getClient()).db('happyHourDB').collection('spots');

			const pipeline = [
				{
					$geoNear: {
						near: { type: 'Point', coordinates: [longitude, latitude] },
						distanceField: 'distance',
						spherical: true,
						maxDistance: 500,
					},
				},
				{
					$match: { happyHours: { $ne: null } },
				},
			];

			const result = await spots.aggregate(pipeline).toArray();

			functions.logger.log('Found spots with distances:', result);

			return result;
		} catch (error) {
			functions.logger.error('Error occurred:', error);
			throw new functions.https.HttpsError('internal', 'Internal Server Error');
		}
	});

interface FindSpotsInAreaPayload {
	boxCoordinates: [[number, number], [number, number]];
}

interface FindSpotsInAreaPayload {
	boxCoordinates: [[number, number], [number, number]];
}

export const findSpotsInArea = functions
	.runWith({ secrets: ['MONGO_DB_CONNECTION_STRING'] })
	.https.onCall(async ({ boxCoordinates }: FindSpotsInAreaPayload) => {
		try {
			functions.logger.log('boxCoordinates', boxCoordinates);
			const spots = (await getClient()).db('happyHourDB').collection('spots');
			const pipeline = [
				{
					$match: {
						coordinates: {
							$geoWithin: {
								$box: boxCoordinates,
							},
						},
						happyHours: { $ne: null },
					},
				},
			];

			const result = await spots.aggregate(pipeline).toArray();
			functions.logger.log('Found spots within area:', result);
			return result;
		} catch (error) {
			functions.logger.error('Error occurred:', error);
			throw new functions.https.HttpsError('internal', 'Internal Server Error');
		}
	});
