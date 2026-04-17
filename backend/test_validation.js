const { leaveValidation } = require('./src/validations/attendanceValidation');

const test1 = leaveValidation({
    reason: 'sick',
    description: 'test',
    dateFrom: new Date().toISOString(),
    dateTo: new Date().toISOString()
});
console.log('Test 1 (same time):', test1.error ? test1.error.details[0].message : 'PASS');

const test2 = leaveValidation({
    reason: 'sick',
    description: 'test',
    dateFrom: new Date(2026, 3, 15).toISOString(),
    dateTo: new Date().toISOString()
});
console.log('Test 2:', test2.error ? test2.error.details[0].message : 'PASS');

const test3 = leaveValidation({
    reason: 'sick',
    description: 'test',
    dateFrom: new Date().toISOString(),
    dateTo: new Date(2026, 3, 15).toISOString()
});
console.log('Test 3 (end date older):', test3.error ? test3.error.details[0].message : 'PASS');

const test4 = leaveValidation({
    reason: 'sick',
    description: 'test',
    dateFrom: '2026-04-15T00:00:00.000',
    dateTo: '2026-04-15T18:24:54.123'
});
console.log('Test 4 (dart format):', test4.error ? test4.error.details[0].message : 'PASS');
