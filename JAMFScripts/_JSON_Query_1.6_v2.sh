LogHead="$(echo "$(date +'%a %b %d %H:%M:%S') $(scutil --get ComputerName) jamf[$$]: ")"
LogIt() {
while read ToLog
do
echo "$LogHead$ToLog" | tee -a "$LogFile"
done
}

jq="/Usr/local/jamf/bin/jq-osx-amd64"

if [ -f "$jq" ]; then
echo $(ls -la $jq) | LogIt
else
curl -LJ0 https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 --output $jq
chmod +x $jq
echo $(ls -la $jq) | LogIt
fi

PullUser() {
UserInfo="$(curl -v -X GET \
-H "Accept: application/json" \
-H "Content-Type: application/json" \
-H "Authorization: SSWS ${api_token}" \
"https://${yourOktaDomain}/api/v1/users?q=$user&limit=1")"
}

UserToVars() {
Email=$(echo $UserInfo | $jq -r '.[].profile | .email')
echo $Email | LogIt
Dept=$(echo $UserInfo | $jq -r '.[].profile | .department')
echo $Dept | LogIt
LastName=$(echo $UserInfo | $jq -r '.[].profile | .lastName')
echo $LastName | LogIt
}