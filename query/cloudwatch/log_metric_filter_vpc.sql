with filter_data as (
  select
    trail.account_id,
    trail.name as trail_name,
    trail.is_logging,
    split_part(trail.log_group_arn, ':', 7) as log_group_name,
    filter.name as filter_name,
    action_arn as topic_arn,
    alarm.metric_name,
    alarm.name as alarm_name,
    subscription.subscription_arn,
    filter.filter_pattern
  from
    aws_cloudtrail_trail as trail,
    jsonb_array_elements(trail.event_selectors) as se,
    aws_cloudwatch_log_metric_filter as filter,
    aws_cloudwatch_alarm as alarm,
    jsonb_array_elements_text(alarm.alarm_actions) as action_arn,
    aws_sns_topic_subscription as subscription
  where
    trail.is_multi_region_trail is true
    and trail.is_logging
    and se ->> 'ReadWriteType' = 'All'
    and trail.log_group_arn is not null
    and filter.log_group_name = split_part(trail.log_group_arn, ':', 7)
    and filter.filter_pattern ~ '\s*\$\.eventName\s*=\s*CreateVpc.+\$\.eventName\s*=\s*DeleteVpc.+\$\.eventName\s*=\s*ModifyVpcAttribute.+\$\.eventName\s*=\s*AcceptVpcPeeringConnection.+\$\.eventName\s*=\s*CreateVpcPeeringConnection.+\$\.eventName\s*=\s*DeleteVpcPeeringConnection.+\$\.eventName\s*=\s*RejectVpcPeeringConnection.+\$\.eventName\s*=\s*AttachClassicLinkVpc.+\$\.eventName\s*=\s*DetachClassicLinkVpc.+\$\.eventName\s*=\s*DisableVpcClassicLink.+\$\.eventName\s*=\s*EnableVpcClassicLink'
    and alarm.metric_name = filter.metric_transformation_name
    and subscription.topic_arn = action_arn
)
select
  -- Required Columns
  'arn:' || a.partition || ':::' || a.account_id as resource,
  case
    when f.trail_name is null then 'alarm'
    else 'ok'
  end as status,
  case
    when f.trail_name is null then 'No log metric filter and alarm exist for VPC changes.'
    else filter_name || ' forwards events for VPC changes.'
  end as reason,
  -- Additional Dimensions
  a.account_id
from
  aws_account as a
  left join filter_data as f on a.account_id = f.account_id
limit 1
