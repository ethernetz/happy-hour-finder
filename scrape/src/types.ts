export interface SpotFromYelp {
	name: string;
	address: string;
	url: string;
}

export type Spot = SpotWithHappyHours | SpotWithoutHappyHours;

export interface SpotWithHappyHours extends SpotBase {
	checkedForHappyHours: true;
	happyHours: HappyHour[];
}

export interface SpotWithoutHappyHours extends SpotBase {
	checkedForHappyHours: false;
}

export interface SpotBase {
	_id: string;
	name: string;
	uniqueName: string;
	address: string;
	url: string;
	coordinates: GeoJSONPoint;
	checkedForHappyHours: boolean;
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
