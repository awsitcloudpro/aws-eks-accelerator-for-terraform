ARG FLUENTD_VERSION=v1.14-windows-ltsc2019-1
ARG AWS_REGION=us-east-2
ARG AWS_ACCOUNT_ID

FROM ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/fluentd:${FLUENTD_VERSION} as base

RUN gem install aws-sdk-cloudwatchlogs \
  && gem install fluent-plugin-concat \
  && gem install fluent-plugin-rewrite-tag-filter  \
  && gem install fluent-plugin-multi-format-parser \
  && gem install fluent-plugin-kubernetes_metadata_filter \
  && gem install fluent-plugin-cloudwatch-logs \
  && gem install fluent-plugin-prometheus \
  && gem sources --clear-all \
  && del C:\ruby27\lib\ruby\gems\2.7.0\cache\*.gem
