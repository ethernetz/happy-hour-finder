export interface SpotFromYelp {
	name: string;
	address: string;
	yelpRedirectUrl: string | null;
}

export type Spot = SpotWithHappyHours | SpotWithoutHappyHours | SpotWithoutUrl;

export interface SpotWithHappyHours extends SpotBase {
	checkedForHappyHours: true;
	happyHours: HappyHour[] | null;
	url: string;
}

export interface SpotWithoutHappyHours extends SpotBase {
	checkedForHappyHours: false;
	url: string;
}

export interface SpotWithoutUrl extends SpotBase {
	checkedForHappyHours: true;
	happyHours: null;
	url: null;
}

export interface SpotBase {
	name: string;
	uniqueName: string;
	address: string;
	url: string | null;
	coordinates: GeoJSONPoint;
	checkedForHappyHours: boolean;
	googlePlaceId: string;
}

export interface HappyHour {
	day: string;
	startTime: string;
	endTime: string;
	deal: string;
	crossesMidnight: boolean;
}

export interface GeoJSONPoint {
	type: 'Point';
	coordinates: [number, number]; // [longitude, latitude]
}
