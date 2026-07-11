package serializers

// All returns registered serializers in a stable display order.
func All() []BenchSerializer {
	return []BenchSerializer{
		// JSON family
		newEncodingJSON(),
		newSonicJSON(),
		newGoccyJSON(),
		newJSONIter(),
		newSegmentioJSON(),
		newUgorjiJSON(),
		// Binary schemaless
		newVmihailencoMsgpack(),
		newShamatonMsgpack(),
		newUgorjiMsgpack(),
		newFxamackerCBOR(),
		newUgorjiCBOR(),
		newKelindarBinary(),
		newEncodingGob(),
		newMongoBSON(),
		// Text document formats
		newGoccyYAML(),
		newPelletierTOML(),
		// Schema / IDL
		newGoogleProtobuf(),
		newHambaAvro(),
		newLinkedInGoavro(),
	}
}
