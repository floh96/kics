package Cx

import data.generic.k8s as k8s_lib
import data.generic.common as common_lib

strongCiphers = [
    "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
    "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
    "TLS_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_RSA_WITH_AES_128_GCM_SHA256",
]

CxPolicy[result] {
	resource := input.document[i]
	metadata := resource.metadata
	specInfo := k8s_lib.getSpecInfo(resource)
	types := {"initContainers", "containers"}
	container := specInfo.spec[types[x]][j]
	common_lib.inArray(container.command, "kube-apiserver")
	not k8s_lib.startWithFlag(container,"--tls-cipher-suites")

	result := {
		"documentId": input.document[i].id,
		"searchKey": sprintf("metadata.name={{%s}}.%s.%s.name={{%s}}.command", [metadata.name, specInfo.path, types[x], container.name]),
		"issueType": "MissingAttribute",
		"keyExpectedValue":  "TLS cipher suites should use strong ciphers",
		"keyActualValue": "TLS cipher suites are not defined",
	}
}

command = {"kube-apiserver", "kubelet"}

CxPolicy[result] {
	resource := input.document[i]
	metadata := resource.metadata
	specInfo := k8s_lib.getSpecInfo(resource)
	types := {"initContainers", "containers"}
	container := specInfo.spec[types[x]][j]
    cmd := command[_]
	common_lib.inArray(container.command, cmd)
    hasWeakCipher(container,"--tls-cipher-suites")

	result := {
		"documentId": input.document[i].id,
		"searchKey": sprintf("metadata.name={{%s}}.%s.%s.name={{%s}}.command", [metadata.name, specInfo.path, types[x], container.name]),
		"issueType": "IncorrectValue",
		"keyExpectedValue":  "TLS cipher suites should use strong ciphers",
		"keyActualValue": "TLS cipher suites uses a weak cipher",
	}
}

CxPolicy[result] {
	doc :=input.document[i]
    doc.kind == "KubeletConfiguration"
    not common_lib.valid_key(doc, "tlsCipherSuites")

	result := {
		"documentId": doc.id,
		"searchKey": sprintf("kind={{%s}}", ["KubeletConfiguration"]),
		"issueType": "MissingAttribute",
		"keyExpectedValue": "TLS cipher suites should use strong ciphers",
		"keyActualValue": "TLS cipher suites are not defined",
	}
}

CxPolicy[result] {
	doc :=input.document[i]
    doc.kind == "KubeletConfiguration"
    ciphers := split(doc.tlsCipherSuites, ",")
    cipher := ciphers[_]
    not common_lib.inArray(strongCiphers,cipher)
	 
	result := {
		"documentId": doc.id,
		"searchKey": sprintf("kind={{%s}}", ["KubeletConfiguration"]),
		"issueType": "IncorrectValue",
		"keyExpectedValue":  "TLS cipher suites should use strong ciphers",
		"keyActualValue": "TLS cipher suites uses a weak cipher",
	}
}

hasWeakCipher(container,flag){
	cipherSplit(container.command, flag)
} else {
	cipherSplit(container.args, flag)
}

cipherSplit(arr,item){
	element := arr[_]
	startswith(element, item)
    options := split(element, "=")
    ciphers := split(options[1], ",")
    cipher := ciphers[_]
    not common_lib.inArray(strongCiphers,cipher)
}
