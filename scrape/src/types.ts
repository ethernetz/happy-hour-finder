export interface SpotFromYelp {
	name: string;
	address: string;
	url: string;
}

export interface Spot {
	_id: string;
	name: string;
	uniqueName: string;
	address: string;
	url: string;
	coordinates: GeoJSONPoint;
	happyHours: HappyHour[];
}

export interface HappyHour {
	day: string;
	startTime: string;
	endTime: string;
	deal: string;
}

export interface GeoJSONPoint {
	type: 'Point';
	coordinates: [number, number]; // [longitude, latitude]
}
