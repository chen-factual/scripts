#! /bin/bash
hadoop jar ./hew-hdfs-index.jar mapreduce.HdfsIndex \
    -D mapred.job.name="Build HEW Step Index" \
    n1xx_cluster.properties \
    hdfs_dest=/user/chen/resolve-tmp/hdfs-index-grouped/ \
    view_id=ZrY9yY \
    dataset_id=Wu8mjQ \
    base_path=/apps/extract/poi/ItalyScarecrow/output \
    run_name=20140523_181617_PDT_italy_pod_batchsummary_bm02-140523-181617-pehewi-633-3.17 \
    hew_step=030_grouped_deduped_entities
