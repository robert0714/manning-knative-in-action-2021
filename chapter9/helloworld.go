package main

import (
	"fmt"
	"net/http"
)

const page = `
<!DOCTYPE html>
<html>
<head>
    <title>Hello, Knative!</title>
</head>
<body>
    <h1>Hello, Knative!</h1>
    <p>See? We made it!</p>
</body>
</html>
`

func main() {
	fmt.Println("OK, here goes...")
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, page)
	})
	http.ListenAndServe(":8080", nil)
}
