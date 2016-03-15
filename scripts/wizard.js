/* To install all dependencies do:
*     	npm -g install optimist request-promise bluebird
*		Full credit for this goes to Mikhail Karasik, EMC Dev
*		Minor edits by James Scott, EMC SE 
 */
 
 
var optimist    = require('optimist'),
    rp          = require('request-promise'),
    Promise     = require('bluebird'),
    readFile    = Promise.promisify(require('fs').readFile),

    cliConfig = optimist
    .usage('Handy script to do automatic CLC post-deploy configuration')
    .alias('h', 'help')     .describe('h', 'Print help and exit')
    .alias('a', 'addr')     .default('a', 'https://192.168.116.148').describe('a', 'Address of the CLC to connect')
    .alias('s', 'secpwd')   .default('s', 'tHHoGinI')     .describe('s', 'secadmin password')
    .alias('u', 'user')     .default('u', 'james')           .describe('u', 'Name of the user to create')
    .alias('p', 'password') .default('p', 'tsFt45tqb$$r2')  .describe('p', 'Password of the user to create')
    .alias('l', 'license')  .default('l', 'license.lic')    .describe('l', 'License file name')
    .alias('k', 'key')      .default('k', 'backup.pem')     .describe('k', 'Backup key')
    .alias('b', 'backup')   .default('b', 'backup.bak')     .describe('b', 'Backup file')
    .alias('n', 'name')   	.default('n','cloudlink1.example.com')	.describe('n', 'Server name')
    .alias('w', 'workflow') .default('w', 'new')        .describe('w', 'Workflow name: restore, new, join')
    .alias('c', 'code')     .default('c', 'tsFt45tq4$')  .describe('c', 'Lockbox code')
    .alias('r', 'resetpw')  .describe('r', 'Re-set secadmin password to user password. Only for \'new\' workflow')
    .alias('d', 'dns')                                      .describe('d', 'DNS server IP adress')
    .alias('j', 'join')     .default('j', '127.0.0.1')      .describe('j', 'Address of CLC to join during \'join\' workflow')
    .alias('i', 'rempwd')   .default('i', 'tsFt45tq4$')  .describe('i', 'Password of the master\'s secadmin')
    ;

	
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"	
	
function printError(error, msg)
{
    var message = '\n[ERROR]\n';

    if (error.response)
    {
        message += error.response.request.method + ' -> ' + error.response.request.uri.href + '\n';
        message += 'Status Code: ' + error.response.statusCode + '\n' + JSON.stringify(error.response.body) + '\n';
    }

    process.stderr.write(message);
}

var argv = cliConfig.argv;

if (argv.h)
{
    cliConfig.showHelp();
}
else
{
    var secadminPassword = argv.s,
        remSecadminPassword = argv.i,
        userName = argv.u,
        userPassword = argv.p,
        licenseFileName = argv.l,
        backupKeyFileName = argv.k,
        backupFileName = argv.b,
        serverName = argv.n,
        baseUrl = argv.a,
        workflow = argv.w,
        lockbox_code = argv.c,
        dns = argv.d,
        is_update_secadmin_pwd = !!argv.r;
        join_addr = argv.j,
        loginSecadminUrl = baseUrl + '/cloudlink/oauth/token?grant_type=client_credentials&client_id=secadmin&client_secret=' + secadminPassword + '&scope=built_in_client',
        loginUserUrl = baseUrl + '/cloudlink/oauth/token?grant_type=client_credentials&client_id=' + userName + '&client_secret=' + userPassword + '&scope=all',
        logoutUrl = baseUrl + '/cloudlink/rest/auth',
        licenseUploadUrl = baseUrl + '/cloudlink/rest/license',
        licensesListUrl = baseUrl + '/cloudlink/rest/license',
        assignLicenseUrl = baseUrl + '/cloudlink/rest/license',
        setNameUrl = baseUrl + '/cloudlink/rest/cluster/server_name',
        restoreUrl = baseUrl + '/cloudlink/rest/backup',
        backupGetKeyUrl = baseUrl + '/cloudlink/rest/auth/backup/key',
        lockboxCodeUrl = baseUrl + '/cloudlink/rest/lockbox/codes',
        lockboxModeUrl = baseUrl + '/cloudlink/rest/lockbox/mode',
        secadminPwdUrl = baseUrl + '/cloudlink/rest/users/secadmin/password',
        setDnsUrl = baseUrl + '/cloudlink/rest/dns',
        joinClusterUrl = baseUrl + '/cloudlink/rest/cluster/join',

        approvedNetworkUrl = baseUrl + '/cloudlink/rest/securevm/network',
        machineGroupUrl = baseUrl + '/cloudlink/rest/securevm/groups',
        machinesUrl = baseUrl + '/cloudlink/rest/securevm',

        createuserUrl = baseUrl + '/cloudlink/rest/users',
        createUserBody = { 'name': userName, 'roles': [ 'SecAdmin' ], 'user_type': 'client', 'password': userPassword },
        assignLicenseBody = { 'start_date': new Date().toJSON() },
        setNameBody = { 'address': serverName },
        lockboxCodeBody = { 'codes': [ lockbox_code ] },
        lockboxModeBody = { 'auto': true },
        secadminPwdBody = { 'new_password': userPassword, 'first_login_change': false },
        setDnsBody = { 'ip': dns },
        joinClusterBody = { 'host': join_addr, 'rem_password': remSecadminPassword , 'rem_user': 'secadmin'},

        approvedNetworkBody = { 'name': 'network','description': 'created'},
        approvedNetworkIpBody = {ip: '192.168.42.0/24', name: 'network'},
        machineGroupBody =     {'networks': ['network'], 'encryption_policy': 'encrypt_all'}

        req = rp.defaults({ 'headers': { 'Content-Type': 'application/json' }});

    /*
     *
     */
    function set_access_token(response)
    {
        var token = JSON.parse(response).access_token;
        process.stdout.write('Access token: ' + token + '\n');
        req = req.defaults({ 'headers': { 'Authorization': 'Bearer ' + token }});
    }

    function create_new_user()
    {
        process.stdout.write('Creating user: ' + userName + '\n');
        return req({ 'method': 'POST', 'uri':  createuserUrl, 'body': JSON.stringify(createUserBody) });
    }

    function log_out()
    {
        process.stdout.write('Logging out...\n');
        return req({ 'method': 'DELETE', 'uri':  logoutUrl });
    }

    function log_in_as_user()
    {
        process.stdout.write('Logging on as ' + userName + '\n');
        return req({ 'method': 'POST', 'uri':  loginUserUrl });
    }

    function log_in_as_secadmin()
    {
        process.stdout.write('Logging on as secadmin\n');
        return req({ 'method': 'POST', 'uri':  loginSecadminUrl });
    }

    function read_license_file()
    {
        process.stdout.write('Reading license file ' + licenseFileName + '\n');
        return readFile(licenseFileName);
    }

    function upload_license_file(licenseFile)
    {
        process.stdout.write('Uploading license file: ' + licenseFile.length + ' bytes\n');
        return req({ 'method': 'POST', 'uri': licenseUploadUrl, 'formData': { 'product': 'vm', 'file': { 'value': licenseFile, options: { 'filename': licenseFileName }}} });
    }

    function get_license_id()
    {
        return new Promise(function (resolve, reject)
        {
            process.stdout.write('Getting list of licenses\n');
            req({ 'method': 'GET', 'uri':  licensesListUrl })
            .then(function (response)
            {
                var licenseId = JSON.parse(response)[0].id;
                process.stdout.write('License id: ' + licenseId + '\n');
                resolve(licenseId);
            })
            .catch(function (error) { reject(error); });
        });
    }

    function assign_license(licenseId)
    {
        process.stdout.write('Assigning license ' + licenseId + '\n');
        return req({ 'method': 'PUT', 'uri': assignLicenseUrl + '/' + licenseId + '/assign?product=vm', 'body': JSON.stringify(assignLicenseBody) });
    }

    function set_server_name()
    {
        process.stdout.write('Setting server name ' + serverName + '\n');
        return req({ 'method': 'PUT', 'uri': setNameUrl, 'body': JSON.stringify(setNameBody) });
    }

    function read_backup_files()
    {
        process.stdout.write('Reading backup key file ' + backupKeyFileName + ' and backup file ' + backupFileName + '\n');
        return Promise.all([ readFile(backupKeyFileName), readFile(backupFileName) ]);
    }

    function restore_from_backup(files)
    {
        process.stdout.write('Backup key size ' + files[0].length + ' bytes. Backup size ' + files[1].length + ' bytes\n');
        process.stdout.write('Doing restore\n');

        return new Promise(function (resolve, reject)
        {
            req({ 'method': 'POST', 'uri':  restoreUrl, 'formData': {
                'backup_file': { 'value': files[1], options: { 'filename': backupFileName }},
                'key_file': { 'value': files[0], options: { 'filename': backupKeyFileName }} }})
            .then(function () { resolve(); })
            .catch(function (error)
            {
                if (error.error.code == 'ECONNRESET')
                    resolve();
                reject(error);
            });
        });
    }

    function get_backup_key_url()
    {
        process.stdout.write('Getting backup key URL\n');
        return req({ 'method': 'GET', 'uri':  backupGetKeyUrl });
    }

    function download_backup_key(response)
    {
        var link = JSON.parse(response).link;
        process.stdout.write('Downloading backup key from ' + link + '\n');
        return req({ 'method': 'GET', 'uri':  baseUrl + '/cloudlink/rest/' + link });
    }

    function set_lockbox_code()
    {
        process.stdout.write('Setting lockbox code to ' + lockbox_code + '\n');
        return req({ 'method': 'PUT', 'uri':  lockboxCodeUrl, 'body': JSON.stringify(lockboxCodeBody) });
    }

    function set_lockbox_mode()
    {
        process.stdout.write('Setting lockbox mode auto\n');
        return req({ 'method': 'PUT', 'uri':  lockboxModeUrl, 'body': JSON.stringify(lockboxModeBody) });
    }

    function update_secadmin_password()
    {
        process.stdout.write('Setting secadmin password to ' + userPassword + '\n');
        return req({ 'method': 'PUT', 'uri':  secadminPwdUrl, 'body': JSON.stringify(secadminPwdBody) });
    }

    function set_dns()
    {
        process.stdout.write('Adding DNS server ' + dns + '\n');
        return req({ 'method': 'POST', 'uri': setDnsUrl, 'body': JSON.stringify(setDnsBody) });
    }

    function join_cluster()
    {
        process.stdout.write('Joining cluster ' + join_addr + '\n');
        return req({ 'method': 'PUT', 'uri': joinClusterUrl, 'body': JSON.stringify(joinClusterBody) });
    }

    /* custom flow, create and assign network */
    function create_network()
    {
        process.stdout.write('Creating network\n');
        return new Promise(function (resolve, reject) {
            req({'method': 'POST', 'uri': approvedNetworkUrl, 'body': JSON.stringify(approvedNetworkBody)})
            .then(function (response) {
                    process.stdout.write('Adding address\n');
                    req({'method': 'POST', 'uri': approvedNetworkUrl + '/network/ip', 'body': JSON.stringify(approvedNetworkIpBody)})
                    .then(function (response) {
                            process.stdout.write('Modifying group\n');
                            req({'method': 'PUT', 'uri': machineGroupUrl + '/Default', 'body': JSON.stringify(machineGroupBody)})
                            .then(function (response) {
                                resolve();
                            })
                            .catch(function (error) {
                                reject(error);
                            });
                    })
                    .catch(function (error) {
                        reject(error);
                    });
            })
            .catch(function (error) {
                reject(error);
            });
        });
    }

    function list_machines()
    {
        return new Promise(function (resolve, reject) {
            req({'method': 'GET', 'uri': machinesUrl})
                .then(function (response) {
                    var parsed = JSON.parse(response);
                    for (var i = 0; i < parsed.length; ++i)
                    {
                        var line = parsed[i].name + '(' + parsed[i].uuid + ') ' + parsed[i].status;
                        for (var j = 0; j < parsed[i].resources.length; ++j)
                        {
                            line += ' ' + parsed[i].resources[j].mpoint + '(' + parsed[i].resources[j].state + ':' + parsed[i].resources[j].percentage + ')';
                        }

                        process.stdout.write(line + '\n');
                    }

                    resolve();
                })
                .catch(function (error) {
                    reject(error);
                });
        });
    }

    function handle_error(error)
    {
        printError(error);
        process.exit(1);
    }

    /*
     * Workflows
     */
    if (workflow === 'restore')
    {   
        process.stdout.write(':: Starting \'restore\' workflow ::\n\n');
		log_in_as_secadmin()
        .then(set_access_token)
        .then(create_new_user)
        .then(log_out)
        .then(log_in_as_user)
        .then(set_access_token)
        .then(read_license_file)
        .then(upload_license_file)
        .then(get_license_id)
	    .then(assign_license);
        if (serverName)
            p = p.then(set_server_name);
        p.then(read_backup_files)
        .then(restore_from_backup)
        .catch(handle_error);
    }
    else if (workflow === 'new')
    {
        process.stdout.write(':: Starting \'new\' workflow ::\n\n');
		process.stdout.write('POST' + loginSecadminUrl + '\n\n');
        var p = log_in_as_secadmin()
        .then(set_access_token)
        .then(create_new_user)
        .then(log_out)
        .then(log_in_as_user)
        .then(set_access_token)
        .then(read_license_file)
        .then(upload_license_file)
        .then(get_license_id)
        .then(assign_license)
		
        if (serverName)
            p = p.then(set_server_name);
        p.then(get_backup_key_url)
        .then(download_backup_key)
        .then(set_lockbox_code)
        .then(set_lockbox_mode)
		
        .catch(handle_error);

        if (is_update_secadmin_pwd)
			p.then(update_secadmin_password);
		
  

    }
    else if (workflow === 'join')
    {
        process.stdout.write(':: Starting \'join\' workflow ::\n\n');

        var p = log_in_as_secadmin()
        .then(set_access_token)
        .then(create_new_user)
        .then(log_out)
        .then(log_in_as_user)
        .then(set_access_token)
        if (serverName)
            p = p.then(set_server_name);
        if (dns)
            p = p.then(set_dns);
        p.then(join_cluster)
        .catch(handle_error);
    }
    else if (workflow === 'custom')
    {
        process.stdout.write(':: Starting \'custom\' workflow ::\n\n');

        var p = log_in_as_user()
            .then(set_access_token)
            .then(create_network)
            .catch(handle_error);
    }
    else if (workflow === 'listvms')
    {
        process.stdout.write(':: Starting \'listvms\' workflow ::\n\n');

        var p = log_in_as_user()
            .then(set_access_token)
            .then(list_machines)
            .catch(handle_error);
    }
}
