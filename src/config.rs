use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct FileConfig {
    pub filename: String,
    pub regex: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Config {
    pub webhook_url: String,
    pub files: Vec<FileConfig>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_yaml::from_str;

    #[test]
    fn test_config_deserialization() {
        let yaml = r#"
        webhook_url: https://discord.com/api/webhooks/test
        files:
          - filename: test1.log
            regex: ERROR.*
          - filename: test2.log
            regex: WARNING.*
        "#;

        let config: Config = from_str(yaml).unwrap();

        assert_eq!(config.webhook_url, "https://discord.com/api/webhooks/test");
        assert_eq!(config.files.len(), 2);
        assert_eq!(config.files[0].filename, "test1.log");
        assert_eq!(config.files[0].regex, "ERROR.*");
        assert_eq!(config.files[1].filename, "test2.log");
        assert_eq!(config.files[1].regex, "WARNING.*");
    }
}
