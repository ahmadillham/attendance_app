const Joi = require('joi');

const attendanceValidation = (data) => {
    const schema = Joi.object({
        status: Joi.string().valid('present', 'absent', 'leave').required(),
        meetingCount: Joi.number().integer().min(1).max(16).optional(),
        courseId: Joi.string().required(),
        latitude: Joi.number().min(-90).max(90).required(),
        longitude: Joi.number().min(-180).max(180).required(),
    });
    return schema.validate(data);
};

const leaveValidation = (data) => {
    const schema = Joi.object({
        reason: Joi.string().valid('sick', 'family', 'academic', 'emergency', 'other').required(),
        description: Joi.string().max(500).allow('', null),
        dateFrom: Joi.date().iso().required(),
        dateTo: Joi.date().iso().min(Joi.ref('dateFrom')).required(),
    });
    return schema.validate(data);
};

module.exports = { attendanceValidation, leaveValidation };
