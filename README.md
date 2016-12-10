
milight-ble
===========

Library to control MiLight/LimitlessLED Bluetooth RGB LED bulbs.


Example
-------

```javascript
const Bulb = require('milight-ble')

Bulb.discover(function(error, bulbs) {
    if (error) throw error
    console.log('Found', bulbs.length, 'bulbs')
    bulbs.forEach(function(bulb) {
        const hue = Math.random()
        console.log('Turning on', bulb.name, 'and setting hue to', ~~(hue * 360))
        bulb.turnOn(function(error) {
            if (error) throw error
            bulb.setColor(~~(hue * 255), 100)
        })
    })
})
```


API
---

Documented inline for now, see `src/bulb.coffee`.


License
-------

MIT
