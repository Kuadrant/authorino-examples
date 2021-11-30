const express = require('express');

const app = express();

app.use('/', express.static(__dirname + '/'))

const server = app.listen(3000, () => {
  console.log("Listening on port %s", server.address().port)
})
