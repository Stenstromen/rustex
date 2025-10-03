use crate::config::FileConfig;
use crate::discord;
use regex::Regex;
use std::fs::File;
use std::io::{self, BufRead, Seek, SeekFrom};
use std::time::Duration;
use tokio::runtime::Runtime;
use tokio::task::spawn_blocking;
use tokio::time;

pub async fn monitor_file(
    config: FileConfig,
    webhook_url: String,
) -> Result<(), Box<dyn std::error::Error>> {
    let re = Regex::new(&config.regex)?;
    let filename = config.filename.clone();

    let mut file = File::open(&filename)?;

    let mut last_position = file.seek(SeekFrom::End(0))?;

    println!("Tailing file {}. Waiting for new content...", filename);

    loop {
        time::sleep(Duration::from_millis(100)).await;

        let file_size = match file.metadata() {
            Ok(metadata) => metadata.len(),
            Err(e) => {
                eprintln!("Error getting file metadata: {}", e);
                continue;
            }
        };

        if file_size > last_position {
            if let Err(e) = file.seek(SeekFrom::Start(last_position)) {
                eprintln!("Error seeking in file: {}", e);
                continue;
            }

            let reader = io::BufReader::new(&file);

            for line in reader.lines().map_while(Result::ok) {
                if re.is_match(&line) {
                    println!("New match in {}: {}", filename, line);

                    let filename_clone = filename.clone();
                    let line_clone = line.clone();
                    let webhook_clone = webhook_url.clone();

                    spawn_blocking(move || {
                        let rt: Runtime = Runtime::new().unwrap();
                        rt.block_on(discord::post_to_discord(
                            &filename_clone,
                            &line_clone,
                            &webhook_clone,
                        ));
                    });
                }
            }

            last_position = match file.stream_position() {
                Ok(pos) => pos,
                Err(e) => {
                    eprintln!("Error getting current position: {}", e);
                    continue;
                }
            };
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::OpenOptions;
    use std::io::Write;
    use std::path::PathBuf;
    use tempfile::tempdir;
    use tokio::time::{sleep, timeout};

    async fn setup_test_file(content: &str) -> (PathBuf, FileConfig, tempfile::TempDir) {
        let dir = tempdir().unwrap();
        let file_path = dir.path().join("test.log");

        let mut file = OpenOptions::new()
            .write(true)
            .create(true)
            .open(&file_path)
            .unwrap();

        writeln!(file, "{}", content).unwrap();

        let config = FileConfig {
            filename: file_path.to_str().unwrap().to_string(),
            regex: "ERROR.*".to_string(),
        };

        (file_path, config, dir)
    }

    #[tokio::test]
    async fn test_regex_matching() {
        let (_path, config, _temp_dir) = setup_test_file("2023-01-01 INFO: Starting app\n").await;

        let re = Regex::new(&config.regex).unwrap();
        assert!(!re.is_match("2023-01-01 INFO: Starting app"));
        assert!(re.is_match("ERROR: Something went wrong"));
    }

    #[tokio::test]
    async fn test_file_monitoring() {
        let (path, config, _temp_dir) = setup_test_file("2023-01-01 INFO: Starting app\n").await;

        let webhook_url = "https://example.com/webhook".to_string();

        let monitor_task = tokio::spawn(async move {
            let _ = timeout(
                Duration::from_millis(200),
                monitor_file(config, webhook_url),
            )
            .await;
        });

        sleep(Duration::from_millis(50)).await;
        let mut file = OpenOptions::new().append(true).open(&path).unwrap();
        writeln!(file, "ERROR: This should trigger a match").unwrap();

        sleep(Duration::from_millis(100)).await;

        monitor_task.abort();
    }
}
