// Creates the Observations table in DynamoDB Local. In AWS, Terraform owns the table.
import { CreateTableCommand, DynamoDBClient, ResourceInUseException } from "@aws-sdk/client-dynamodb";
import { requireEnv } from "../src/lib/env.ts";

const table = requireEnv("TABLE");
const client = new DynamoDBClient({ endpoint: requireEnv("DYNAMODB_ENDPOINT") });

try {
  await client.send(
    new CreateTableCommand({
      TableName: table,
      BillingMode: "PAY_PER_REQUEST",
      AttributeDefinitions: [
        { AttributeName: "location", AttributeType: "S" },
        { AttributeName: "ts", AttributeType: "S" },
      ],
      KeySchema: [
        { AttributeName: "location", KeyType: "HASH" },
        { AttributeName: "ts", KeyType: "RANGE" },
      ],
    }),
  );
  console.log(`Created table ${table}`);
} catch (error) {
  if (!(error instanceof ResourceInUseException)) throw error;
  console.log(`Table ${table} already exists`);
}
