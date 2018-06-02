#!/bin/sh

test_description='test git-http-backend respects CONTENT_LENGTH'
. ./test-lib.sh

verify_http_result() {
	# sometimes there is fatal error buit the result is still 200
	if grep 'fatal:' act.err
	then
		return 1
	fi

	if ! grep "Status" act.out >act
	then
		printf "Status: 200 OK\r\n" >act
	fi
	printf "Status: $1\r\n" >exp &&
	test_cmp exp act
}

test_http_env() {
	handler_type="$1"
	shift
	env \
		CONTENT_TYPE="application/x-git-$handler_type-pack-request" \
		QUERY_STRING="/repo.git/git-$handler_type-pack" \
		PATH_TRANSLATED="$PWD/.git/git-$handler_type-pack" \
		GIT_HTTP_EXPORT_ALL=TRUE \
		REQUEST_METHOD=POST \
		"$@"
}

test_expect_success 'setup repository' '
	test_commit c0 &&
	test_commit c1
'

hash_head=$(git rev-parse HEAD)
hash_prev=$(git rev-parse HEAD~1)

cat >fetch_body <<EOF
0032want $hash_head
00000032have $hash_prev
0009done
EOF

gzip -k fetch_body

head -c -10 <fetch_body.gz >fetch_body.gz.trunc

head -c -10 <fetch_body >fetch_body.trunc

hash_next=$(git commit-tree -p HEAD -m next HEAD^{tree})
printf '00790000000000000000000000000000000000000000 %s refs/heads/newbranch\0report-status\n0000' "$hash_next" >push_body
echo "$hash_next" | git pack-objects --stdout >>push_body

gzip -k push_body

head -c -10 <push_body.gz >push_body.gz.trunc

head -c -10 <push_body >push_body.trunc

touch empty_body

test_expect_success 'fetch plain' '
	test_http_env upload \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl fetch_body git http-backend >act.out 2>act.err &&
	verify_http_result "200 OK"
'

test_expect_success 'fetch plain truncated' '
	test_http_env upload \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl fetch_body.trunc git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'fetch plain empty' '
	test_http_env upload \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl empty_body git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'fetch gzipped' '
	test_http_env upload \
		HTTP_CONTENT_ENCODING="gzip" \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl fetch_body.gz git http-backend >act.out 2>act.err &&
	verify_http_result "200 OK"
'

test_expect_success 'fetch gzipped truncated' '
	test_http_env upload \
		HTTP_CONTENT_ENCODING="gzip" \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl fetch_body.gz.trunc git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'fetch gzipped empty' '
	test_http_env upload \
		HTTP_CONTENT_ENCODING="gzip" \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl empty_body git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'push plain' '
	git config http.receivepack true &&
	test_http_env receive \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl push_body git http-backend >act.out 2>act.err &&
	verify_http_result "200 OK" &&
	git rev-parse newbranch >act.head &&
	echo "$hash_next" >exp.head &&
	test_cmp act.head exp.head &&
	git branch -D newbranch
'


test_expect_success 'push plain truncated' '
	git config http.receivepack true &&
	test_http_env receive \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl push_body.trunc git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'push plain empty' '
	git config http.receivepack true &&
	test_http_env receive \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl empty_body git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'push gzipped' '
	test_http_env receive \
		HTTP_CONTENT_ENCODING="gzip" \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl push_body.gz git http-backend >act.out 2>act.err &&
	verify_http_result "200 OK" &&
	git rev-parse newbranch >act.head &&
	echo "$hash_next" >exp.head &&
	test_cmp act.head exp.head &&
	git branch -D newbranch
'

test_expect_success 'push gzipped truncated' '
	test_http_env receive \
		HTTP_CONTENT_ENCODING="gzip" \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl push_body.gz.trunc git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_expect_success 'push gzipped empty' '
	test_http_env receive \
		HTTP_CONTENT_ENCODING="gzip" \
		"$TEST_DIRECTORY"/t5562/invoke-with-content-length.pl empty_body git http-backend >act.out 2>act.err &&
	test_must_fail verify_http_result "200 OK"
'

test_done
