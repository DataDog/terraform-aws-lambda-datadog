// Minimal hello-world workload duplicated from serverless-self-monitoring
// (lambda-managed-instances/handlers/default/nodejs). Tracing is auto-injected by the
// Datadog layers and logs are auto-collected by the extension, so no tracer setup is
// needed here. It emits one log line carrying the run id so logs can be correlated.
exports.handler = async function (_event, _context) {
    console.log(JSON.stringify({ message: "hello from one-e2e", run_id: process.env.ONE_E2E_RUN_ID }));

    return {
        statusCode: 200,
        body: "hello, world",
    };
};
