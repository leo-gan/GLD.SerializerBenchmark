// esbuild entry for the Dagr TypeScript emitted by `dagr build` into src/generated/dagr/
// (schemas/v2/dagr/schema.py). Every suite type exists in four node layouts; the export
// names are <Type><Flavour><Kind> with Flavour '' (packed), Regular, Frozen, FrozenPacked.
// Lazy readers for all four; direct builders for the packed-rooted graphs (packed,
// frozen+packed); arena + arena serializer for regular and frozen (no direct builder).
// src/serializers/dagr.js looks the modules up by these names.
export * as MessageLazy from '../src/generated/dagr/MessageGraph';
export * as MessageDirect from '../src/generated/dagr/MessageGraph_direct';
export * as MessageRegularLazy from '../src/generated/dagr/MessageRegularGraph';
export * as MessageRegularArena from '../src/generated/dagr/MessageRegularGraph_arena';
export * as MessageRegularSerde from '../src/generated/dagr/MessageRegularGraph_serde';
export * as MessageFrozenLazy from '../src/generated/dagr/MessageFrozenGraph';
export * as MessageFrozenArena from '../src/generated/dagr/MessageFrozenGraph_arena';
export * as MessageFrozenSerde from '../src/generated/dagr/MessageFrozenGraph_serde';
export * as MessageFrozenPackedLazy from '../src/generated/dagr/MessageFrozenPackedGraph';
export * as MessageFrozenPackedDirect from '../src/generated/dagr/MessageFrozenPackedGraph_direct';
export * as DocumentLazy from '../src/generated/dagr/DocumentGraph';
export * as DocumentDirect from '../src/generated/dagr/DocumentGraph_direct';
export * as DocumentRegularLazy from '../src/generated/dagr/DocumentRegularGraph';
export * as DocumentRegularArena from '../src/generated/dagr/DocumentRegularGraph_arena';
export * as DocumentRegularSerde from '../src/generated/dagr/DocumentRegularGraph_serde';
export * as DocumentFrozenLazy from '../src/generated/dagr/DocumentFrozenGraph';
export * as DocumentFrozenArena from '../src/generated/dagr/DocumentFrozenGraph_arena';
export * as DocumentFrozenSerde from '../src/generated/dagr/DocumentFrozenGraph_serde';
export * as DocumentFrozenPackedLazy from '../src/generated/dagr/DocumentFrozenPackedGraph';
export * as DocumentFrozenPackedDirect from '../src/generated/dagr/DocumentFrozenPackedGraph_direct';
export * as TelemetryLazy from '../src/generated/dagr/TelemetryGraph';
export * as TelemetryDirect from '../src/generated/dagr/TelemetryGraph_direct';
export * as TelemetryRegularLazy from '../src/generated/dagr/TelemetryRegularGraph';
export * as TelemetryRegularArena from '../src/generated/dagr/TelemetryRegularGraph_arena';
export * as TelemetryRegularSerde from '../src/generated/dagr/TelemetryRegularGraph_serde';
export * as TelemetryFrozenLazy from '../src/generated/dagr/TelemetryFrozenGraph';
export * as TelemetryFrozenArena from '../src/generated/dagr/TelemetryFrozenGraph_arena';
export * as TelemetryFrozenSerde from '../src/generated/dagr/TelemetryFrozenGraph_serde';
export * as TelemetryFrozenPackedLazy from '../src/generated/dagr/TelemetryFrozenPackedGraph';
export * as TelemetryFrozenPackedDirect from '../src/generated/dagr/TelemetryFrozenPackedGraph_direct';
export * as StringsLazy from '../src/generated/dagr/StringsGraph';
export * as StringsDirect from '../src/generated/dagr/StringsGraph_direct';
export * as StringsRegularLazy from '../src/generated/dagr/StringsRegularGraph';
export * as StringsRegularArena from '../src/generated/dagr/StringsRegularGraph_arena';
export * as StringsRegularSerde from '../src/generated/dagr/StringsRegularGraph_serde';
export * as StringsFrozenLazy from '../src/generated/dagr/StringsFrozenGraph';
export * as StringsFrozenArena from '../src/generated/dagr/StringsFrozenGraph_arena';
export * as StringsFrozenSerde from '../src/generated/dagr/StringsFrozenGraph_serde';
export * as StringsFrozenPackedLazy from '../src/generated/dagr/StringsFrozenPackedGraph';
export * as StringsFrozenPackedDirect from '../src/generated/dagr/StringsFrozenPackedGraph_direct';
export * as EventLazy from '../src/generated/dagr/EventGraph';
export * as EventDirect from '../src/generated/dagr/EventGraph_direct';
export * as EventRegularLazy from '../src/generated/dagr/EventRegularGraph';
export * as EventRegularArena from '../src/generated/dagr/EventRegularGraph_arena';
export * as EventRegularSerde from '../src/generated/dagr/EventRegularGraph_serde';
export * as EventFrozenLazy from '../src/generated/dagr/EventFrozenGraph';
export * as EventFrozenArena from '../src/generated/dagr/EventFrozenGraph_arena';
export * as EventFrozenSerde from '../src/generated/dagr/EventFrozenGraph_serde';
export * as EventFrozenPackedLazy from '../src/generated/dagr/EventFrozenPackedGraph';
export * as EventFrozenPackedDirect from '../src/generated/dagr/EventFrozenPackedGraph_direct';
export { Builder } from '../src/generated/dagr/dagr_writer';
