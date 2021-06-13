// storage service, for persisting high scores and game config. will use
// window.localStorage if available, otherwise will just store in memory.
// all values should be Uint8Array objects.

function _createMemoryStorage() {
    const dict = {};

    function setItem(key, value) {
        dict[key] = value;
    }

    function getItem(key) {
        return key in dict ? dict[key] : null;
    }

    return {
        setItem: setItem,
        getItem: getItem,
    };
}

function _createLocalStorage(local_storage) {
    function setItem(key, value) {
        const value_encoded = base64js.fromByteArray(value);
        local_storage.setItem(key, value_encoded);
    }

    function getItem(key) {
        const value_encoded = local_storage.getItem(key);
        if (value_encoded !== null) {
            return base64js.toByteArray(value_encoded);
        } else {
            return null;
        }
    }

    return {
        setItem: setItem,
        getItem: getItem,
    };
}

function getStorage(diagnostics_feature) {
    let local_storage = null;

    try {
        local_storage = window.localStorage;
    } catch (_) {
        // could be SecurityError
    }

    if (!local_storage) {
        diagnostics_feature.setAvailability(false);
        return _createMemoryStorage();
    }

    diagnostics_feature.setAvailability(true);
    return _createLocalStorage(local_storage);
}
