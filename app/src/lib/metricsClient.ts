import { CloudWatchClient, PutMetricDataCommand } from "@aws-sdk/client-cloudwatch";

const client = new CloudWatchClient({});

export async function putObservationAge(namespace: string, location: string, ageMinutes: number): Promise<void> {
  await client.send(
    new PutMetricDataCommand({
      Namespace: namespace,
      MetricData: [
        {
          MetricName: "ObservationAgeMinutes",
          Dimensions: [{ Name: "Location", Value: location }],
          Value: ageMinutes,
          Unit: "None",
        },
      ],
    }),
  );
}
