// MiniUser golden vectors G1–G5 (Serialization 401 lab appendix).
// Run: rustc miniuser_goldens.rs && ./miniuser_goldens
// Teaching subset only — not production Protobuf / prost.

#[derive(Clone)]
struct MiniUser {
    id: u32,
    name: String,
    manager: Option<Box<MiniUser>>,
    tags: Vec<u32>,
}

fn encode_varint(mut u: u64, out: &mut Vec<u8>) {
    while u > 0x7f {
        out.push((u as u8 & 0x7f) | 0x80);
        u >>= 7;
    }
    out.push(u as u8 & 0x7f);
}

fn encode_key(field_number: u32, wire_type: u32, out: &mut Vec<u8>) {
    encode_varint(((field_number << 3) | wire_type) as u64, out);
}

fn encode_mini_user(u: &MiniUser) -> Vec<u8> {
    let mut out = Vec::new();
    if u.id != 0 {
        encode_key(1, 0, &mut out);
        encode_varint(u.id as u64, &mut out);
    }
    if !u.name.is_empty() {
        let b = u.name.as_bytes();
        encode_key(2, 2, &mut out);
        encode_varint(b.len() as u64, &mut out);
        out.extend_from_slice(b);
    }
    if let Some(m) = &u.manager {
        let inner = encode_mini_user(m);
        encode_key(3, 2, &mut out);
        encode_varint(inner.len() as u64, &mut out);
        out.extend_from_slice(&inner);
    }
    for t in &u.tags {
        encode_key(4, 0, &mut out);
        encode_varint(*t as u64, &mut out);
    }
    out
}

fn hex_decode(s: &str) -> Vec<u8> {
    if s.is_empty() {
        return Vec::new();
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).expect("hex"))
        .collect()
}

fn main() {
    let cases: Vec<(&str, MiniUser, &str)> = vec![
        (
            "G1",
            MiniUser {
                id: 1,
                name: "Ada".into(),
                manager: None,
                tags: vec![],
            },
            "08011203416461",
        ),
        (
            "G2",
            MiniUser {
                id: 0,
                name: String::new(),
                manager: None,
                tags: vec![],
            },
            "",
        ),
        (
            "G3",
            MiniUser {
                id: 300,
                name: String::new(),
                manager: None,
                tags: vec![],
            },
            "08ac02",
        ),
        (
            "G4",
            MiniUser {
                id: 0,
                name: String::new(),
                manager: None,
                tags: vec![1, 2],
            },
            "20012002",
        ),
        (
            "G5",
            MiniUser {
                id: 0,
                name: String::new(),
                manager: Some(Box::new(MiniUser {
                    id: 2,
                    name: String::new(),
                    manager: None,
                    tags: vec![],
                })),
                tags: vec![],
            },
            "1a020802",
        ),
    ];

    let mut failed = false;
    for (label, user, want_hex) in cases {
        let got = encode_mini_user(&user);
        let want = hex_decode(want_hex);
        if got != want {
            eprintln!("FAIL {label}: got {:02x?} want {:02x?}", got, want);
            failed = true;
        } else if got.is_empty() {
            println!("OK {label}: <empty>");
        } else {
            print!("OK {label}: ");
            for (i, b) in got.iter().enumerate() {
                if i > 0 {
                    print!(" ");
                }
                print!("{b:02x}");
            }
            println!();
        }
    }
    if failed {
        std::process::exit(1);
    }
}
