### Summary
This PAT model was created to evaluate changes proposed in CCR1150. The proposed changes essentially remove the reference syystems 
and require the reference and propsed buildings to use the same system.

The assessment approach taken was to model a medium office in Toronto with a standard system and an advanced system (GSHP plus DOAS was selected). 
A third model was created with the advanced system and reduced opaque wall R-values to compare against the initial two models.

Results show that the model with the advanced HVAC uses about a third less energy than the model with the standard system. The third model shows that
by using the advanced system in the current code framework the exterior wall R-values could be halved and the building would comply with Part 8.

### Openstudio version info
BTAP and NRCan openstudio server were used to run the models as follows:
OpenStudio server 2.6.0-nrcan
OpenStudio Standards 0.2.3 git:e23ea76
OpenStudio CLI 2.6.0.8c81faf8bc
BTAP sha-1: d5579c6961b1f8a12ad9418da90f0d5903ecfe0b

### Models

### Measures
The change envelope R-value measure was edited to allow reduced R-values (by default lower values are ignored)
The change roof R-value measure was edited to allow reduced R-values (by default lower values are ignored)
The GSHP and DOAS script was altered to apply the system to all space types that have a defined usage (i.e. do not contain 'undefined' 
in the space type name)

### Results
