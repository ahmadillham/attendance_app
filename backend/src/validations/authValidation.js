const Joi = require('joi');

const registerValidation = (data) => {
    const schema = Joi.object({
        studentId: Joi.string().required(),
        name: Joi.string().required(),
        email: Joi.string().email().required(),
        phone: Joi.string().allow('', null),
        department: Joi.string().required(),
        faculty: Joi.string().required(),
        semester: Joi.number().integer().min(1).required(),
        password: Joi.string().min(6).required(),
    });
    return schema.validate(data);
};

const loginValidation = (data) => {
    const schema = Joi.object({
        studentId: Joi.string().required(),
        password: Joi.string().required()
    });
    return schema.validate(data);
};

module.exports = { registerValidation, loginValidation };
