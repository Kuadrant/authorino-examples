USE a12nserver;

INSERT INTO principals(identity, nickname, type, active, created_at, modified_at)
VALUES ('mailto:admin@demo', 'admin', 1, 1, now(), now()), /* id=1 */
       ('http://talker-api-authorino.127.0.0.1.nip.io:8000', 'talker-api', 2, 1, now(), now()), /* id=2 */
       ('http://demo.app', 'consumer', 2, 1, now(), now()); /* id=3 */

INSERT INTO user_passwords(password)
VALUES (0x243262243132244479635462675A55464866662F784A45474B31774B75646979647537386B46394833554259554F4269785942746479364D67726D32); /* admin:123456 */

INSERT INTO user_privileges(user_id, resource, privilege)
VALUES (1, '*', 'admin'),
       (3, 'talker-api', 'read');

INSERT INTO oauth2_clients(client_id, client_secret, allowed_grant_types, user_id)
VALUES ('talker-api', '$2b$12$NOYmoms7p3YunF6tPUeF/eXlWrs3ijKKxRWjPHCihUZm.qbrzLoT.', '', 2), /* talker-api:V6g-2Eq2ALB1_WHAswzoeZofJ_e86RI4tdjClDDDb4g */
       ('service-account-1', '$2b$12$BSNisFWLcr/ZLMC2zYKnd.CkOM96wZ2JVYDoI/eIO232tmIu6CWti', 'client_credentials refresh_token', 3);  /* service-account-1:DbgXROi3uhWYCxNUq_U1ZXjGfLHOIM8X3C2bJLpeEdE */
