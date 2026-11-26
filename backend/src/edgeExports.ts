// These exact handlers also back Firebase Functions. The free Edge transport
// verifies Firebase Auth and App Check before invoking their .run methods.
export { aiTask, aiTaskStream } from "./aiTask";
export { alternatives } from "./alternatives";
export { scanProduct } from "./scanProduct";
export { requestAccountDeletion } from "./accountDeletion";
