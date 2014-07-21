export INPUTS_PATH=$2
export SUMMARIES_PATH=$3
export PROJECT_NAME=${1:-standalone_solr_index}

current_dir=`dirname "$0"`

echo $PROJECT_NAME
echo $INPUTS_PATH
echo $SUMMARIES_PATH

hadoop jar ${current_dir}/hadoop-extraction-workflow-hadoop.jar workflows.utils.SolrIndexStitchWorkflow \
project_name=$PROJECT_NAME \
standalone_dataset_id="txIgmU" \
standalone_view_id="Iw1HPj" \
standalone_inputs_path=$INPUTS_PATH \
standalone_summaries_path=$SUMMARIES_PATH \
hadoop_config_file="n1xx_cluster.properties" \
extraction_config_class=extract.poi.UnitedStatesScarecrow2 \
email_contact="chen@factual.com"
