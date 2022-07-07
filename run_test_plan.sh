#!/bin/bash
accessKey=$1
secretKey=$2
name=${3}
HOST=${4}
env_name=${5}
testPlan_name=${6}


PROJECT_ID="项目ID"
Env_ID="运行环境ID"
TestPlanId="测试计划ID"
REPORT_URL="获得的REPORT地址"

TestReportId="测试计划执行完后,获取的报告ID"

echo "accessKey ${accessKey}"
echo "secretKey ${secretKey}"

keySpec=$(echo -n "${secretKey}" | od -A n -t x1 | tr -d ' ')
iv=$(echo -n "${accessKey}" | od -A n -t x1 | tr -d ' ')

echo "keySpec: ${keySpec}"
echo "iv: ${iv}"

#currentTimeMillis=$[$(date +%s%N)/1000000]
currentTimeMillis=$(date +%s000)
seed=${accessKey}\|$currentTimeMillis
signature=$(printf %s "${seed}" | openssl enc -e -aes-128-cbc -base64 -K ${keySpec} -iv ${iv})

echo "current time Millis: $currentTimeMillis"
echo "seed: ${seed}"
echo "Signature: ${signature}"



getProjectId()
{	
	RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/project/listAll)
	PROJECT_ID=$(printf '%s\n' "${RESULT}" | jq '.data[] | select(.name == "'"${name}"'")' |jq .id)
}
getEnvId()
{	
	p_id=`echo $1|awk -F "\"" '{print $2}'`
	RESULT=$(curl -k -s -H "accesskey: ${accessKey}" -H "signature: ${signature}" -H "Content-Type: application/json" https://${HOST}/api/environment/list/${p_id})
	Env_ID=$(printf '%s\n' "${RESULT}" | jq '.data[] | select(.name == "'"${env_name}"'")' |jq .id)
}
getTestPlanId()
{	
	p_id=$1
	body='{"components":[{"key":"name","name":"MsTableSearchInput","label":"commons.name","operator":{"value":"like","options":[{"label":"commons.adv_search.operators.like","value":"like"},{"label":"commons.adv_search.operators.not_like","value":"not like"}]}},{"key":"updateTime","name":"MsTableSearchDateTimePicker","label":"commons.update_time","operator":{"options":[{"label":"commons.adv_search.operators.between","value":"between"},{"label":"commons.adv_search.operators.gt","value":"gt"},{"label":"commons.adv_search.operators.ge","value":"ge"},{"label":"commons.adv_search.operators.lt","value":"lt"},{"label":"commons.adv_search.operators.le","value":"le"},{"label":"commons.adv_search.operators.equals","value":"eq"}]}},{"key":"createTime","name":"MsTableSearchDateTimePicker","label":"commons.create_time","operator":{"options":[{"label":"commons.adv_search.operators.between","value":"between"},{"label":"commons.adv_search.operators.gt","value":"gt"},{"label":"commons.adv_search.operators.ge","value":"ge"},{"label":"commons.adv_search.operators.lt","value":"lt"},{"label":"commons.adv_search.operators.le","value":"le"},{"label":"commons.adv_search.operators.equals","value":"eq"}]}},{"key":"principal","name":"MsTableSearchSelect","label":"test_track.plan.plan_principal","operator":{"options":[{"label":"commons.adv_search.operators.in","value":"in"},{"label":"commons.adv_search.operators.not_in","value":"not in"},{"label":"commons.adv_search.operators.current_user","value":"current user"}]},"options":{"url":"/user/ws/current/member/list","labelKey":"name","valueKey":"id"},"props":{"multiple":true}},{"key":"status","name":"MsTableSearchSelect","label":"test_track.plan.plan_status","operator":{"options":[{"label":"commons.adv_search.operators.in","value":"in"},{"label":"commons.adv_search.operators.not_in","value":"not in"}]},"options":[{"label":"test_track.plan.plan_status_prepare","value":"Prepare"},{"label":"test_track.plan.plan_status_running","value":"Underway"},{"label":"test_track.plan.plan_status_completed","value":"Completed"},{"label":"test_track.plan.plan_status_finished","value":"Finished"},{"label":"test_track.plan.plan_status_archived","value":"Archived"}],"props":{"multiple":true}},{"key":"stage","name":"MsTableSearchSelect","label":"test_track.plan.plan_stage","operator":{"options":[{"label":"commons.adv_search.operators.in","value":"in"},{"label":"commons.adv_search.operators.not_in","value":"not in"}]},"options":[{"label":"test_track.plan.smoke_test","value":"smoke"},{"label":"test_track.plan.regression_test","value":"regression"},{"label":"test_track.plan.system_test","value":"system"}],"props":{"multiple":true}}],"orders":[],"projectId":'${p_id}'}'
	RESULT=$(curl -k -s -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H 'Content-Type: application/json' https://${HOST}/test/plan/list/1/10 -X POST -d "$body")
	TestPlanId=$(printf '%s\n' "${RESULT}" | jq '.data.listObject[] | select(.name == "'"${testPlan_name}"'")' |jq .id)
}

test_plan_run()
{
	p_id=$1
	e_id=$2
	t_id=$3
	body='{"mode":"serial","reportType":"iddReport","onSampleError":false,"runWithinResourcePool":false,"resourcePoolId":null,"envMap":{'${p_id}':'${e_id}'},"testPlanId":'${t_id}',"projectId":'${p_id}',"userId":"672cde21-2eed-4007-bc3c-9eb2fad03543","triggerMode":"MANUAL","environmentType":"JSON","environmentGroupId":"","requestOriginator":"TEST_PLAN"}'
	RESULT=$(curl -k -s -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H 'Content-Type: application/json' https://${HOST}/test/plan/run -X POST -d "$body")
	TestReportId=`echo $RESULT | jq -r '.data'`
}

get_report_url()
{
	customData=$1
	body='{"customData":"'${customData}'","shareType":"PLAN_DB_REPORT","lang":null}'
	RESULT=$(curl -k -s -H "accessKey: ${accessKey}" -H "signature: ${signature}" -H 'Content-Type: application/json' https://${HOST}/share/info/generateShareInfoWithExpired -X POST -d "$body")
	REPORT_URL=`echo $RESULT|awk -F "?" '{print $2}'|awk -F "\"" '{print $1}'`
}



getProjectId
echo "PROJECT_ID: ${PROJECT_ID}"

getEnvId $PROJECT_ID
echo "Env_ID: ${Env_ID}"

getTestPlanId $PROJECT_ID
echo "TestPlanId: ${TestPlanId}"

test_plan_run $PROJECT_ID $Env_ID $TestPlanId
echo "测试计划已执行完成" 

get_report_url $TestReportId

REPORT="https://${HOST}/sharePlanReport?${REPORT_URL}"
echo "测试报告地址为: ${REPORT}" 
