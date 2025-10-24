// modules/backend/lambda/index.js
const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB.DocumentClient();

const TABLE_NAME = process.env.TABLE_NAME;
const ITEM_KEY = "visitor-count"; // Static key for the single count item

exports.handler = async (event) => {
    try {
        const params = {
            TableName: TABLE_NAME,
            Key: {
                id: ITEM_KEY
            },
            UpdateExpression: "SET visits = if_not_exists(visits, :start) + :inc",
            ExpressionAttributeValues: {
                ":start": 0,
                ":inc": 1
            },
            ReturnValues: "UPDATED_NEW"
        };

        const result = await ddb.update(params).promise();
        const newCount = result.Attributes.visits;
        
        return {
            statusCode: 200,
            headers: {
                "Access-Control-Allow-Origin": "*", // Required for CORS on the frontend
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                visits: newCount
            })
        };
    } catch (err) {
        console.error("DynamoDB error:", err);
        return {
            statusCode: 500,
            headers: {
                "Access-Control-Allow-Origin": "*"
            },
            body: JSON.stringify({ message: "Internal server error" })
        };
    }
};