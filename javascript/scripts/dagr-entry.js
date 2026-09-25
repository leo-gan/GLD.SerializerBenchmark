// esbuild entry for the Dagr TypeScript emitted by `dagr build` into src/generated/dagr/
// (schemas/v2/dagr/schema.py). Only the lazy readers and the direct builders are used by
// the harness; the arena/serde modules are left out of the bundle.
export * as MessageLazy from '../src/generated/dagr/MessageGraph';
export * as MessageDirect from '../src/generated/dagr/MessageGraph_direct';
export * as DocumentLazy from '../src/generated/dagr/DocumentGraph';
export * as DocumentDirect from '../src/generated/dagr/DocumentGraph_direct';
export * as TelemetryLazy from '../src/generated/dagr/TelemetryGraph';
export * as TelemetryDirect from '../src/generated/dagr/TelemetryGraph_direct';
export * as StringsLazy from '../src/generated/dagr/StringsGraph';
export * as StringsDirect from '../src/generated/dagr/StringsGraph_direct';
export * as EventLazy from '../src/generated/dagr/EventGraph';
export * as EventDirect from '../src/generated/dagr/EventGraph_direct';
export { Builder } from '../src/generated/dagr/dagr_writer';
