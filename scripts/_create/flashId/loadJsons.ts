import * as fs from 'fs';
import * as path from 'path';

export function loadJson(fileDir: string) {
    const filePath = path.join(__dirname, fileDir); // adjust filename
    const rawData = fs.readFileSync(filePath, 'utf-8');
    return JSON.parse(rawData);

}