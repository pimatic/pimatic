rule overview
==============

What's a rule
------------
A rule is a string that has the format: "if _this_ then _that_". The _this_ part will be called 
the condition of the rule and the _that_ part the actions of the rule.

__Examples:__

  * if its 10pm then turn the tv off
  * if its friday and its 8am then turn the light on
  * if (music is playing or the light is on) and somebody is present then turn the speaker on
  * if temperatue of living room is less than 15°C for 5 minutes then log "its getting cold" 

The condition of a rule consists of one or more predicates. The predicates can be combined with
"and", "or" and can be grouped by parentheses.

__for-suffix__

A predicate can have a "for" as a suffix like in "music is playing for 5 seconds" or 
"tv is on for 2 hours". If the predicate has a for-suffix then the rule action is only triggered,
when the predicate stays true the given time. Predicates that represent one time events like "10pm"
can't have a for-suffix because the condition can never hold.

Predicates
-----------

###Built in

Predicate for devices that have a state like switches

  * _device_ is on|off
  * _device_ is switched on|off
  * _device_ is turned on|off

__Examples:__

  * tv is on
  * light is off

Predicates for presence sensors like a motion detector  

  * _device_ is present
  * _device_ is not present
  * _device_ is absent

__Examples:__

  * my smartphone is present

Predicates for comparing device attributes like sensor value or other states.

  * _attribute_ of _device_ is equal to _value_
  * _attribute_ of _device_ equals _value_
  * _attribute_ of _device_ is not _value_
  * _attribute_ of _device_ is less than _value_
  * _attribute_ of _device_ is lower than _value_
  * _attribute_ of _device_ is greater than _value_
  * _attribute_ of _device_ is higher than _value_

__Examples:__

  * temperature of temperature sensor 1 is lower than 15°C
  * humidity of temperature sensor 1 is greater than 60% 

###chron-plugin

Provided by the [cron-plugin](http://www.pimatic.org/docs/pimatic-cron/)

  * its _time_
  * its _weekday_ _time_
  * its _weekday_

__Examples:__

  * its 8am
  * its 8:00
  * its friday 10pm

###mobile-frontend

  * _button text_ is pressed
  * button _button text_ is pressed

__Examples:__

  * watch tv button is pressed

Actions
-------

###Built in

Predicate for devices that can be turned on or off:

  * switch [the] _device_ on|off
  * turn [the] _device_ on|off
  * switch on|off [the] _device_ 
  * turn on|off [the] _device_ 

__Examples:__

  * turn tv on
  * switch the light off

__Logger:__

  * log "_a string_"

Development
------------
Take a look at the [developer documentation](http://www.pimatic.org/docs/lib/rules.html) for how
it works and how to implement your own predicates and actions.