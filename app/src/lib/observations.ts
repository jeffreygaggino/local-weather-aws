import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand, QueryCommand, paginateQuery } from "@aws-sdk/lib-dynamodb";
import type { Observation } from "./observation.ts";

// DYNAMODB_ENDPOINT is only set locally (DynamoDB Local); in AWS the SDK uses the regional endpoint.
const client = new DynamoDBClient({ endpoint: process.env.DYNAMODB_ENDPOINT });
const doc = DynamoDBDocumentClient.from(client);

/** A second write for the same Location and Slot replaces the first. */
export async function putObservation(table: string, observation: Observation): Promise<void> {
  await doc.send(new PutCommand({ TableName: table, Item: observation }));
}

export async function latestObservation(table: string, location: string): Promise<Observation | undefined> {
  const { Items } = await doc.send(
    new QueryCommand({
      TableName: table,
      KeyConditionExpression: "#location = :location",
      ExpressionAttributeNames: { "#location": "location" },
      ExpressionAttributeValues: { ":location": location },
      ScanIndexForward: false,
      Limit: 1,
    }),
  );
  return Items?.[0] as Observation | undefined;
}

/** Observations whose Slot starts at or after `since`, newest first. */
export async function observationsSince(table: string, location: string, since: Date): Promise<Observation[]> {
  const pages = paginateQuery(
    { client: doc },
    {
      TableName: table,
      KeyConditionExpression: "#location = :location AND ts >= :since",
      ExpressionAttributeNames: { "#location": "location" },
      ExpressionAttributeValues: { ":location": location, ":since": since.toISOString() },
      ScanIndexForward: false,
    },
  );
  const observations: Observation[] = [];
  for await (const page of pages) observations.push(...((page.Items ?? []) as Observation[]));
  return observations;
}
