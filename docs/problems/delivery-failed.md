# Delivery Failed

`502 Bad Gateway`, `application/problem+json`. Returned by a consumer through the [Event Intake API](../../intake.openapi.yaml).

The consumer could not handle the event, for example because the System API it calls refused the
request. Event Grid retries the delivery (3 attempts), then dead-letters the event into the tap
storage (`sttapintplatdemo`, container `deadletters`).
