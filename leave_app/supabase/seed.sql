-- 대표(관리자) 계정 1개 만들기. 실행 후 나온 token 으로 접속한다:  https://<배포주소>/?t=<token>
-- 이 토큰은 비밀번호와 같다. 다른 사람에게 공유하지 말 것.
insert into employees (name, role) values ('대표', 'admin')
returning name, token;
