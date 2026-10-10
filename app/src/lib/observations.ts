import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";
import type { Observation } from "./observation.ts";

// DYNAMODB_ENDPOINT is only set locally (DynamoDB Local); in AWS the SDK uses the regional endpoint.
const client = new DynamoDBClient({ endpoint: process.env.DYNAMODB_ENDPOINT });
const doc = DynamoDBDocumentClient.from(client);

/** A second write for the same Location and Slot replaces the first. */
export async function putObservation(table: string, observation: Observation): Promise<void> {
  await doc.send(new PutCommand({ TableName: table, Item: observation }));
}
