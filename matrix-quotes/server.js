const express = require('express')
const app = express()
const axios = require('axios')

const { ENDPOINT, KEYCLOAK_REALM, CLIENT_ID } = process.env

var root = require('path').join(__dirname, '/')
var loginUrl = 'login.html'

app.set('view engine', 'hbs')
app.set('views', root)
app.use(express.static(root))

if (KEYCLOAK_REALM && CLIENT_ID) {
  const baseRedirectUri = `${ENDPOINT}/auth`
  loginUrl = `${KEYCLOAK_REALM}/protocol/openid-connect/auth?client_id=${CLIENT_ID}&redirect_uri=${baseRedirectUri}&scope=openid&response_type=code`

  app.get('/auth', (req, res) => {
    const redirectTo = req.query.redirect_to || '/'
    const redirectUri = (redirectTo != '/') ? `${baseRedirectUri}?redirect_to=${redirectTo}` : baseRedirectUri

    const params = new URLSearchParams()
    params.append('grant_type', 'authorization_code')
    params.append('code', req.query.code)
    params.append('client_id', CLIENT_ID)
    params.append('redirect_uri', redirectUri)

    axios.post(`${KEYCLOAK_REALM}/protocol/openid-connect/token`, params).then(response => {
      const accessToken = response.data.access_token
      res.cookie('TOKEN', accessToken)
      res.redirect(redirectTo)
    }).catch(error => {
      console.log('Error: ' + error.message)
    })
  })
}

app.get(['/index.html', '/'], (_, res) => {
  res.render('index', { loginUrl: loginUrl });
})

const server = app.listen(3000, () => {
  console.log("Listening on port %s", server.address().port)
})
