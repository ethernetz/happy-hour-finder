import { Client, PlaceInputType } from '@googlemaps/google-maps-services-js';
import { GOOGLE_MAPS_API_KEY } from './config.js';

const client = new Client();

export async function getGooglePlaceId(name: string, address: string) {
	try {
		// Concatenating name and address to improve search accuracy
		const searchString = `${name} ${address}`;

		const response = await client.findPlaceFromText({
			params: {
				input: searchString,
				inputtype: PlaceInputType.textQuery,
				key: GOOGLE_MAPS_API_KEY, // Make sure you have set this environment variable
			},
		});

		const placeId = response.data.candidates[0].place_id;

		if (!placeId) throw new Error('No place ID found');

		return placeId;
	} catch (e) {
		console.error('An error occurred:', e);
		throw e;
	}
}
