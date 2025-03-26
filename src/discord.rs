use chrono::Utc;
use reqwest::Client;
use serde_json::json;

pub async fn post_to_discord(filename: &str, line: &str, webhook_url: &str) {
    let timestamp = Utc::now().to_rfc3339();

    let payload = json!({
        "username": "RustEx",
        "avatar_url": "https://rustacean.net/assets/rustacean-flat-happy.png",
        "embeds": [{
            "title": format!("File: {}", filename),
            "description": format!("```rust\n{}\n```", line),
            "color": 0x3498DB,
            "footer": {
                "text": format!("Timestamp: {}", timestamp)
            }
        }]
    });

    let client = Client::new();
    if let Err(e) = client.post(webhook_url).json(&payload).send().await {
        eprintln!("Failed to send Discord webhook: {}", e);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use reqwest::Client;
    use serde_json::Value;

    #[tokio::test]
    async fn test_discord_payload_format() {
        let filename = "test.log";
        let line = "ERROR: Something went wrong";
        let webhook_url = "https://example.com/webhook";

        let mock_client = Client::new();

        let request = mock_client
            .post(webhook_url)
            .json(&json!({
                "username": "RustEx",
                "avatar_url": "https://rustacean.net/assets/rustacean-flat-happy.png",
                "embeds": [{
                    "title": format!("File: {}", filename),
                    "description": format!("```rust\n{}\n```", line),
                    "color": 0x3498DB,
                    "footer": {
                        "text": format!("Timestamp: {}", Utc::now().to_rfc3339())
                    }
                }]
            }))
            .build()
            .unwrap();

        let body = request.body().unwrap();
        let body_str = String::from_utf8(body.as_bytes().unwrap().to_vec()).unwrap();
        let json: Value = serde_json::from_str(&body_str).unwrap();

        assert_eq!(json["username"], "RustEx");
        assert_eq!(json["embeds"][0]["title"], format!("File: {}", filename));
        assert!(
            json["embeds"][0]["description"]
                .as_str()
                .unwrap()
                .contains(line)
        );
    }
}
