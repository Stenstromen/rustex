mod config;
mod discord;
mod monitor;

use config::Config;
use serde_yaml::from_reader;
use std::env;
use std::fs::File;
use tokio::task::spawn;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let config_path = args.get(1).map(|s| s.as_str()).unwrap_or("config.yaml");

    println!("Using config file: {}", config_path);

    let f = File::open(config_path)?;
    let config: Config = from_reader(f)?;

    let webhook_url = config.webhook_url.clone();
    let mut handles = vec![];

    for file_config in config.files {
        let filename: String = file_config.filename.clone();
        let webhook: String = webhook_url.clone();
        let handle = spawn(async move {
            if let Err(e) = monitor::monitor_file(file_config, webhook).await {
                eprintln!("Error monitoring file {}: {}", filename, e);
            }
        });
        handles.push(handle);
    }

    for handle in handles {
        let _ = handle.await;
    }

    Ok(())
}
