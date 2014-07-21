current_dir=`dirname "$0"`

hadoop jar ${current_dir}/../hadoop-extraction-workflow-hadoop.jar workflows.extract.poi.USScarecrow2Workflow json_config=${current_dir}/config.json

