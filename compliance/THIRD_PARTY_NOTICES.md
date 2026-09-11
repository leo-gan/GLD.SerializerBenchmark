# Third-party notices for the compliance corpus

This repository’s own code and original catalog cases are MIT
(see the root `LICENSE`).

## IETF Code Components (RFC 7049 / RFC 8949 Appendix A)

A subset of the encoded byte strings in `compliance/data/cbor/`
matches the “Examples of Encoded CBOR Data Items” tables in:

- RFC 7049, Appendix A
- RFC 8949, Appendix A

Those tables are **Code Components** under the IETF Trust Legal
Provisions and are licensed as follows.

```
Copyright (c) 2013, 2020 IETF Trust and the persons identified as
authors of the code. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in
   the documentation and/or other materials provided with the
   distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived
   from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
```

This code was derived from IETF RFC 7049 and IETF RFC 8949.
Please reproduce this note if possible.

Case identifiers, titles, well-formedness (reject) inputs, and all
non-Appendix-A original extras are original work of this project.

## Official test suites (vendored as catalog JSON)

Full license texts are copied under `compliance/vendor/`.

| Suite | License | Catalog ids |
|-------|---------|-------------|
| nst/JSONTestSuite | MIT (Nicolas Seriot, 2016) | `jts-*` |
| yaml/yaml-test-suite | MIT (Ingy döt Net, 2016–2020) | `yts-*` |
| toml-lang/toml-test | MIT (TOML authors, 2018) | `toml-1.0.0-*`, `toml-1.1.0-*` |
| kawanet/msgpack-test-suite | MIT (Yusuke Kawasaki, 2017–2018) | `mps-*` |
| cbor-wg/cbor-test-vectors | BSD-2-Clause (IETF CBOR WG, 2017) | `cbor-wg-*` |
| amazon-ion/ion-tests | Apache-2.0 (Amazon.com, 2007–2016) | `ion-good-*`, `ion-bad-*` |
| apache/avro `test_io` encodings | Apache-2.0 (ASF) | `avro-io-*` |
| google/flatbuffers `gold_flexbuffer_example.bin` | Apache-2.0 (Google) | `fb-flex-gold` |
