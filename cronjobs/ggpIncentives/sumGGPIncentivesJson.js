const fs = require('fs');
const path = require('path');

// Function to convert timestamp to human-readable format
function timestampToDate(timestamp) {
    const date = new Date(timestamp * 1000); // Multiply by 1000 to convert seconds to milliseconds
    return date.toUTCString(); // Returns date in UTC format
}

// Get all files in the current directory
const files = fs.readdirSync(__dirname);

// Filter files that match the pattern "ggpIncentives_<TIMESTAMP>.json"
const jsonFiles = files.filter(file => /^ggpIncentives_(\d+)\.json$/.test(file));

// Object to accumulate total incentives for each user
let totalIncentivesByUser = {};

// Variable to keep track of the total sum of incentives across all JSON files
let grandTotalIncentives = 0;

jsonFiles.forEach(file => {
    // Extract the timestamp from the filename
    const match = file.match(/^ggpIncentives_(\d+)\.json$/);
    if (match) {
        const timestamp = parseInt(match[1], 10);

        // Read and parse the JSON file
        const filePath = path.join(__dirname, file);
        const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

        // Sum the values in the JSON object
        let sum = 0;
        for (const address in data) {
            if (data.hasOwnProperty(address)) {
                const value = Number(data[address]);
                sum += value;

                // Accumulate the incentives for each user (address)
                if (!totalIncentivesByUser[address]) {
                    totalIncentivesByUser[address] = 0;
                }
                totalIncentivesByUser[address] += value;
            }
        }

        // Add the sum of this file's incentives to the grand total
        grandTotalIncentives += sum;

        // Convert timestamp to human-readable format
        const humanReadableDate = timestampToDate(timestamp);

        // Console log the required information
        console.log(`Filename: ${file}`);
        console.log(`Timestamp: ${humanReadableDate}`);
        console.log(`Sum of values in file: ${sum}`);
        console.log('---------------------------------------');
    }
});

// Write the final JSON file with total incentives for each user (address)
const outputFilePath = path.join(__dirname, 'totalIncentivesByUser.json');
fs.writeFileSync(outputFilePath, JSON.stringify(totalIncentivesByUser, null, 2), 'utf8');

// Log the grand total of all incentives across all JSON files
console.log(`Total sum of incentives across all files: ${grandTotalIncentives}`);

console.log(`Final JSON written to: ${outputFilePath}`);
