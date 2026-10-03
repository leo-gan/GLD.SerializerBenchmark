package serializers

// All returns registered serializers in a stable display order.
func All() []BenchSerializer {
	return []BenchSerializer{
		// JSON family
		newEncodingJSON(),
		newEncodingJSONV2(),
		newSonicJSON(),
		newGoccyJSON(),
		newJSONIter(),
		newSegmentioJSON(),
		newUgorjiJSON(),
		// Binary schemaless
		newVmihailencoMsgpack(),
		newShamatonMsgpack(),
		newShamatonMsgpackArray(),
		newUgorjiMsgpack(),
		newFxamackerCBOR(),
		newUgorjiCBOR(),
		newKelindarBinary(),
		newEncodingGob(),
		newMongoBSON(),
		newAmazonIon(),
		// Text document formats
		newGoccyYAML(),
		newPelletierTOML(),
		// Schema / IDL
		newGoogleProtobuf(),
		newHambaAvro(),
		newLinkedInGoavro(),
		// Columnar / fixed-wire. Stable order.
		newArrowIPC(),
		newParquet(),
		newParquetUncompressed(),
		newSBE(),
	}
}
