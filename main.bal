// import ballerina/http;
// import ballerinax/twilio;

// type Customer record {
//     string name;
//     string license_plate;
//     string vehicle_model;
//     string vehicle_year;
//     string location;
//     string phone;
//     string email;
//     string insurance_policy_no;
// };

// type Service_station record {
//     string name;
//     string location;
//     string working_hours;
//     string services;
//     float rating;
// };

// type AppointmentItem record {
//     string appoint_number;
//     Customer customer;
//     Service_station service_station;
//     string service_date;
//     string service_time;
//     string service_description;
//     boolean confirmed;
// };

// type Appointment record {
//     AppointmentItem[] appointment;
// };

// service /servicestations on new http:Listener(8290) {
//     resource function post categories/[string location]/book(AppointmentItem payload) returns http:Created|http:NotFound|http:InternalServerError {
//     }
// }

// configurable string serviceStationsBackend = "http://localhost:9090";
// // configurable string paymentBackend = "http://localhost:9090/healthcare/payments";
// configurable string host = "smtp.gmail.com";
// configurable string username = ?;
// configurable string password = ?;

// final http:Client ServiceStationsEp = check new (url = serviceStationsBackend);

import ballerina/email;
import ballerina/http;
import ballerina/log;

type Patient record {|
    string name;
    string dob;
    string ssn;
    string address;
    string phone;
    string email;
|};

type Doctor record {|
    string name;
    string hospital;
    string category;
    string availability;
    decimal fee;
|};

type Appointment record {|
    int appointmentNumber;
    Doctor doctor;
    Patient patient;
    boolean confirmed;
    string hospital;
    string appointmentDate;
|};

type Payment record {|
    int appointmentNo;
    string doctorName;
    string patient;
    decimal actualFee;
    int discount;
    decimal discounted;
    string paymentID;
    string status;
|};

type PatientWithCardNo record {|
    *Patient;
    string cardNo;
|};

type ReservationRequest record {|
    PatientWithCardNo patient;
    string doctor;
    string hospital_id;
    string hospital;
    string appointment_date;
|};

type ReservationResponse record {|
    int appointmentNo;
    string doctorName;
    string patient;
    decimal actualFee;
    int discount;
    decimal discounted;
    string paymentID;
    string status;
|};

configurable string hospitalServicesBackend = "http://localhost:9090";
configurable string paymentBackend = "http://localhost:9090/healthcare/payments";
configurable string host = "smtp.gmail.com";
configurable string username = "sahandakshit@gmail.com";
configurable string password = "84091150@";

final http:Client hospitalServicesEP = check new (hospitalServicesBackend);
final http:Client paymentEP = check new (paymentBackend);
final email:SmtpClient smtpClient = check new (host, username, password);

service /healthcare on new http:Listener(8290) {

    resource function post categories/[string category]/reserve(ReservationRequest payload)
            returns http:Created|http:NotFound|http:InternalServerError {

        PatientWithCardNo patient = payload.patient;

        Appointment|http:ClientError appointment =
                hospitalServicesEP->/[payload.hospital_id]/categories/[category]/reserve.post({
            patient: {
                name: patient.name,
                dob: patient.dob,
                ssn: patient.ssn,
                address: patient.address,
                phone: patient.phone,
                email: patient.email
            },
            doctor: payload.doctor,
            hospital: payload.hospital,
            appointment_date: payload.appointment_date
        });

        if appointment !is Appointment {
            log:printError("Appointment reservation failed", appointment);
            if appointment is http:ClientRequestError {
                return <http:NotFound>{body: string `unknown hospital, doctor, or category`};
            }
            return <http:InternalServerError>{body: appointment.message()};
        }

        int appointmentNumber = appointment.appointmentNumber;

        Payment|http:ClientError payment = paymentEP->/.post({
            appointmentNumber,
            doctor: appointment.doctor,
            patient: appointment.patient,
            fee: appointment.doctor.fee,
            confirmed: appointment.confirmed,
            card_number: patient.cardNo
        });

        if payment !is Payment {
            log:printError("Payment settlement failed", payment);
            if payment is http:ClientRequestError {
                return <http:NotFound>{body: string `payment failed: unknown appointment number`};
            }
            return <http:InternalServerError>{body: payment.message()};
        }

        email:Error? sendMessage = smtpClient->sendMessage({
            to: patient.email,
            subject: "Appointment reservation confirmed at " + payload.hospital,
            body: getEmailContent(appointmentNumber, appointment, payment)
        });

        if sendMessage is email:Error {
            return <http:InternalServerError>{body: sendMessage.message()};
        }
        return <http:Created>{};
    }
}

function getEmailContent(int appointmentNumber, Appointment appointment, Payment payment)
        returns string =>
    let Patient patient = appointment.patient, Doctor doctor = appointment.doctor in
    string `Appointment Confirmation

    Appointment Details
        Appointment Number: ${appointmentNumber}
        Appointment Date: ${appointment.appointmentDate}

    Patient Details
        Name: ${patient.name}
        Contact Number: ${patient.phone}

    Doctor Details
        Name: ${doctor.name}
        Specialization: ${doctor.category}

    Payment Details
        Doctor Fee: ${payment.actualFee}
        Discount: ${payment.discount}
        Total Fee: ${payment.discounted}
        Payment Status: ${payment.status}`;