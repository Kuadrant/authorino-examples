document.getElementById('form-login').addEventListener('submit', (e) => {
  e.preventDefault()
  const form = e.target

  const token = window.btoa(form.username.value + ':' + form.password.value)
  document.cookie = 'TOKEN=' + token

  const redirectTo = new URLSearchParams(window.location.search.substr(1))
  const target = redirectTo.get('redirect_to') ? redirectTo.get('redirect_to') : '/index.html'
  window.open(target, '_self')
})
